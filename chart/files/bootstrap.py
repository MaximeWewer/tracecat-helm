"""Reconcile declared workflows and secrets into a Tracecat workspace.

Run by the bootstrap Job (templates/bootstrap-job.yaml) inside the Tracecat
backend image, with the same environment as the API. It talks to the database
through Tracecat's own services (no REST API, no user token needed):

- workflows: every *.yaml / *.yml / *.json file under BOOTSTRAP_WORKFLOWS_DIR is
  a Git-sync style workflow document (RemoteWorkflowDefinition: id, alias,
  folder_path, tags, webhook, case_trigger, definition) plus two extensions:
  `status` (online|offline, applied to the workflow) and `schedules[].inputs`
  (schedule trigger inputs, which Git sync does not carry). Workflows are
  overwritten by id, schedules are replaced only when they differ.
- secrets: BOOTSTRAP_SECRETS_FILE lists workspace secrets; each key names the
  env var holding its value (injected from values or Kubernetes Secrets).
  Secrets are created or updated in place, never deleted.

Idempotent: a re-run with the same inputs changes nothing but the workflow
definition version. Exits non-zero on any failure so the Job retries.
"""

from __future__ import annotations

import asyncio
import json
import os
import sys
import time
from pathlib import Path
from typing import Any

import yaml
from sqlalchemy import select

from tracecat.auth.types import Role
from tracecat.contexts import ctx_role
from tracecat.db.engine import get_async_session_bypass_rls_context_manager
from tracecat.db.models import Workflow, Workspace
from tracecat.db.rls import set_rls_context_from_role
from tracecat.exceptions import TracecatNotFoundError
from tracecat.identifiers.workflow import WorkflowUUID
from tracecat.secrets.schemas import SecretCreate, SecretKeyValue, SecretUpdate
from tracecat.secrets.service import SecretsService
from tracecat.workflow.schedules.schemas import ScheduleCreate
from tracecat.workflow.schedules.service import WorkflowSchedulesService
from tracecat.workflow.store.import_service import WorkflowImportService
from tracecat.workflow.store.schemas import RemoteWorkflowDefinition

WORKSPACE_NAME = os.environ.get("BOOTSTRAP_WORKSPACE", "Default Workspace")
WORKFLOWS_DIR = Path(os.environ.get("BOOTSTRAP_WORKFLOWS_DIR", "/bootstrap/workflows"))
SECRETS_FILE = Path(os.environ.get("BOOTSTRAP_SECRETS_FILE", "/bootstrap/config/secrets.json"))
WAIT_SECONDS = int(os.environ.get("BOOTSTRAP_WAIT_SECONDS", "600"))
SCHEDULE_FIELDS = ("cron", "every", "offset", "start_at", "end_at", "timeout", "status", "inputs")


def log(msg: str) -> None:
    print(f"[bootstrap] {msg}", flush=True)


def load_workflow_docs() -> list[tuple[str, dict[str, Any]]]:
    if not WORKFLOWS_DIR.is_dir():
        return []
    docs = []
    for path in sorted(WORKFLOWS_DIR.iterdir()):
        # ConfigMap volumes also hold `..data` / `..<timestamp>` entries.
        if path.suffix not in (".yaml", ".yml", ".json") or path.name.startswith(".."):
            continue
        doc = yaml.safe_load(path.read_text())
        if not isinstance(doc, dict):
            raise ValueError(f"{path.name}: expected a mapping")
        docs.append((path.name, doc))
    return docs


def load_secret_specs() -> list[dict[str, Any]]:
    if not SECRETS_FILE.is_file():
        return []
    return json.loads(SECRETS_FILE.read_text())


async def resolve_role() -> Role:
    """Wait for the migrations and the API startup (which seeds the default
    workspace), then build a platform-superuser service role for the workspace."""
    deadline = time.monotonic() + WAIT_SECONDS
    while True:
        try:
            async with get_async_session_bypass_rls_context_manager() as session:
                ws = (
                    await session.execute(
                        select(Workspace)
                        .where(Workspace.name == WORKSPACE_NAME)
                        .order_by(Workspace.created_at)
                        .limit(1)
                    )
                ).scalar_one_or_none()
            if ws is not None:
                break
            reason = f"workspace {WORKSPACE_NAME!r} not found yet"
        except Exception as e:  # DB not ready / tables not migrated yet
            reason = f"database not ready: {e.__class__.__name__}: {e}"
        if time.monotonic() > deadline:
            raise RuntimeError(f"gave up after {WAIT_SECONDS}s: {reason}")
        log(f"waiting: {reason}")
        await asyncio.sleep(10)
    log(f"workspace {ws.name!r} id={ws.id} org={ws.organization_id}")
    return Role(
        type="service",
        service_id="tracecat-bootstrap",
        organization_id=ws.organization_id,
        workspace_id=ws.id,
        is_platform_superuser=True,
        scopes=frozenset({"*"}),
    )


async def import_workflows(role: Role, docs: list[tuple[str, dict[str, Any]]]) -> None:
    remotes: list[RemoteWorkflowDefinition] = []
    extras: list[tuple[str, str | None, list[dict[str, Any]] | None]] = []
    for name, doc in docs:
        doc = dict(doc)
        status = doc.pop("status", None)
        schedules = doc.pop("schedules", None)
        remote = RemoteWorkflowDefinition.model_validate(doc)
        remotes.append(remote)
        extras.append((remote.id, status, schedules))
        log(f"workflow {remote.id} ({remote.definition.title}) <- {name}")

    async with get_async_session_bypass_rls_context_manager() as session:
        await set_rls_context_from_role(session, role)
        result = await WorkflowImportService(session=session, role=role).import_workflows_atomic(
            remotes, commit_sha="helm-bootstrap", sync_schedules=False
        )
    if not result.success:
        for d in result.diagnostics:
            log(f"ERROR {d.workflow_path} [{d.error_type}] {d.message} {d.details}")
        raise RuntimeError(result.message)
    log(result.message)

    for wf_id, status, schedules in extras:
        await apply_status_and_schedules(role, wf_id, status, schedules)


def _normalize(params: ScheduleCreate) -> dict[str, Any]:
    data = params.model_dump(include=set(SCHEDULE_FIELDS))
    data["inputs"] = data.get("inputs") or {}
    data["timeout"] = data.get("timeout") or 0
    return data


async def apply_status_and_schedules(
    role: Role, wf_id: str, status: str | None, schedules: list[dict[str, Any]] | None
) -> None:
    wf_uuid = WorkflowUUID.new(wf_id)
    async with get_async_session_bypass_rls_context_manager() as session:
        await set_rls_context_from_role(session, role)
        if status is not None:
            workflow = await session.scalar(
                select(Workflow).where(
                    Workflow.workspace_id == role.workspace_id, Workflow.id == wf_uuid
                )
            )
            if workflow is None:
                raise RuntimeError(f"workflow {wf_id} missing after import")
            if workflow.status != status:
                workflow.status = status
                session.add(workflow)
                log(f"workflow {wf_id} status -> {status}")
        # schedules absent = leave the workflow's schedules alone; [] = remove all.
        if schedules is not None:
            desired = [ScheduleCreate(workflow_id=wf_uuid, **s) for s in schedules]
            service = WorkflowSchedulesService(session=session, role=role)
            existing = await service.list_schedules(workflow_id=wf_uuid)
            current = sorted(
                (
                    _normalize(
                        ScheduleCreate(
                            workflow_id=wf_uuid,
                            **{f: getattr(s, f) for f in SCHEDULE_FIELDS if f != "timeout"},
                            timeout=s.timeout or 0,
                        )
                    )
                    for s in existing
                ),
                key=repr,
            )
            wanted = sorted((_normalize(p) for p in desired), key=repr)
            if current != wanted:
                await service.replace_schedules(wf_uuid, desired, commit=False)
                log(f"workflow {wf_id} schedules replaced ({len(desired)})")
        await session.commit()


async def reconcile_secrets(role: Role, specs: list[dict[str, Any]]) -> None:
    for spec in specs:
        name = spec["name"]
        environment = spec.get("environment") or "default"
        keys = []
        for k in spec["keys"]:
            value = os.environ.get(k["env"])
            if value is None:
                raise RuntimeError(f"secret {name}: env {k['env']} for key {k['key']} is unset")
            keys.append(SecretKeyValue(key=k["key"], value=value))
        async with get_async_session_bypass_rls_context_manager() as session:
            await set_rls_context_from_role(session, role)
            service = SecretsService(session=session, role=role)
            try:
                secret = await service.get_secret_by_name(name, environment=environment)
            except TracecatNotFoundError:
                secret = None
            if secret is None:
                await service.create_secret(
                    SecretCreate(
                        type=spec.get("type", "custom"),
                        name=name,
                        description=spec.get("description"),
                        keys=keys,
                        environment=environment,
                    )
                )
                log(f"secret {name} ({environment}) created")
                continue
            current = {
                kv.key: kv.value.get_secret_value()
                for kv in service.decrypt_keys(secret.encrypted_keys)
            }
            wanted = {kv.key: kv.value.get_secret_value() for kv in keys}
            if current == wanted and secret.description == spec.get("description"):
                log(f"secret {name} ({environment}) unchanged")
                continue
            await service.update_secret(
                secret, SecretUpdate(description=spec.get("description"), keys=keys)
            )
            log(f"secret {name} ({environment}) updated")


async def main() -> int:
    docs = load_workflow_docs()
    specs = load_secret_specs()
    log(f"{len(docs)} workflow(s), {len(specs)} secret(s) declared")
    role = await resolve_role()
    ctx_role.set(role)
    # Secrets first: workflows may reference them, and they never fail validation.
    await reconcile_secrets(role, specs)
    if docs:
        await import_workflows(role, docs)
    log("done")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(asyncio.run(main()))
    except Exception as e:
        log(f"FAILED: {e.__class__.__name__}: {e}")
        sys.exit(1)

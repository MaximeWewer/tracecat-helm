# Tracecat Helm

Operator-first, vendor-neutral, with the full component topology and bundled dependencies.

## Architecture

**Tracecat components** (single backend image, command-overridden):

| Component | Command | Notes |
|-----------|---------|-------|
| `api` | (default) | FastAPI, `:8000`, `/api/health` |
| `ui` | (default) | Next.js, `:3000` |
| `worker` | `tracecat.dsl.worker` | Temporal workflow worker |
| `executor` | `tracecat.executor.worker` | Action executor (runs integration code) |
| `agent-worker` | `tracecat.agent.worker` | Temporal worker for the agent queue |
| `agent-executor` | `tracecat.agent.executor_worker` | Agent action executor |
| `litellm` | `tracecat.agent.litellm` | LLM gateway, `:4000` |
| `mcp` | `tracecat.mcp` | MCP server, `:8099` (opt-in, requires OIDC) |

Plus a `migrations` Job (alembic) and a `temporal-setup` post-install hook.

**Bundled dependencies:** Temporal (subchart), 2× CloudNative-PG `Cluster` (app + temporal, PG 17), Redis (CloudPirates), S3 (RustFS, standalone).

## Prerequisites

- Kubernetes **1.25+**, Helm **3+**.
- **CloudNative-PG operator** installed cluster-wide (this chart ships only the `Cluster` CRs):
  ```sh
  helm repo add cnpg https://cloudnative-pg.github.io/charts
  helm upgrade --install cnpg cnpg/cloudnative-pg -n cnpg-system --create-namespace
  ```
- Optional, only if you enable the matching feature:
  - **KEDA** operator — for `keda.enabled` autoscaling.
  - **Prometheus Operator** CRDs — for `tracecat.temporal.metrics.serviceMonitor.enabled` / `cnpg.monitoring.enablePodMonitor`.
  - **Gateway API** CRDs + controller (Kubernetes 1.29+ for `v1`) — for `gatewayApi.enabled`.

## Install

```sh
helm dependency build
helm install tracecat . -n tracecat --create-namespace \
  --set tracecat.auth.superadminEmail=admin@example.com
```

Secrets are generated automatically (see `bridgeSecrets`). On first sign-in, register the superadmin email to claim the admin account.

## Exposure (pick one)

| Mode | Key | Notes |
|------|-----|-------|
| Ingress | `ingress.enabled` | Path routing `/`→ui, `/api`→api, `/mcp`→mcp on one host (recommended). |
| Gateway API | `gatewayApi.enabled` | `HTTPRoute` (combined or `split`); set `parentRefs`. |
| Istio | `virtualService.enabled` | VirtualService(s). |

The UI enforces a same-origin CSP — serve UI and API on the **same host** (any of the above), not via split port-forwards.

## Test

```sh
helm test tracecat -n tracecat   # checks api /api/health
```

## Notes / gotchas

- Major PostgreSQL version changes are **not** in-place upgrades — recreate the cluster.
- The Temporal subchart's schema job runs as a **normal Job** (`temporal.schema.useHelmHooks=false`) to avoid a deadlock with async CNPG provisioning.
- Temporal SQL uses the modern `postgres12_pgx` (pgx) driver.
- `executor` / `agent-executor` (arbitrary integration code) and `litellm` (writes a runtime config under `/app`) run with a **writable** root filesystem; all other components are read-only.

## Requirements

Kubernetes: `>=1.25.0-0`

| Repository | Name | Version |
|------------|------|---------|
| https://charts.rustfs.com | rustfs | 0.8.0 |
| https://go.temporal.io/helm-charts | temporal | 1.2.0 |
| oci://registry-1.docker.io/cloudpirates | redis | 0.30.4 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| agentExecutor.backend | string | `"ephemeral"` |  |
| agentExecutor.contextCompression.enabled | bool | `false` |  |
| agentExecutor.contextCompression.thresholdKb | int | `16` |  |
| agentExecutor.llmGateway.credentialCacheTtlSeconds | string | `"60"` |  |
| agentExecutor.llmGateway.healthcheckIntervalSeconds | string | `"30"` |  |
| agentExecutor.llmProxyReadTimeout | string | `"300"` |  |
| agentExecutor.maxConcurrentActivities | string | `"1"` |  |
| agentExecutor.queue | string | `"shared-agent-executor-queue"` |  |
| agentExecutor.replicas | int | `2` |  |
| agentExecutor.resources.limits.cpu | string | `"4000m"` |  |
| agentExecutor.resources.limits.memory | string | `"16384Mi"` |  |
| agentExecutor.resources.requests.cpu | string | `"2000m"` |  |
| agentExecutor.resources.requests.memory | string | `"4096Mi"` |  |
| agentExecutor.serviceAccount.annotations | object | `{}` |  |
| agentExecutor.serviceAccount.create | bool | `false` |  |
| agentExecutor.serviceAccount.name | string | `""` |  |
| agentExecutor.workerPoolSize | string | `""` |  |
| agentWorker.contextCompression.enabled | bool | `false` |  |
| agentWorker.contextCompression.thresholdKb | int | `16` |  |
| agentWorker.executorClientTimeout | string | `"300"` |  |
| agentWorker.queue | string | `"shared-agent-queue"` |  |
| agentWorker.replicas | int | `2` |  |
| agentWorker.resources.limits.cpu | string | `"2000m"` |  |
| agentWorker.resources.limits.memory | string | `"2048Mi"` |  |
| agentWorker.resources.requests.cpu | string | `"1000m"` |  |
| agentWorker.resources.requests.memory | string | `"2048Mi"` |  |
| agentWorker.serviceAccount.annotations | object | `{}` |  |
| agentWorker.serviceAccount.create | bool | `false` |  |
| agentWorker.serviceAccount.name | string | `""` |  |
| api.replicas | int | `2` |  |
| api.resources.limits.cpu | string | `"2000m"` |  |
| api.resources.limits.memory | string | `"4096Mi"` |  |
| api.resources.requests.cpu | string | `"2000m"` |  |
| api.resources.requests.memory | string | `"4096Mi"` |  |
| autoscaling.agentExecutor.enabled | bool | `true` |  |
| autoscaling.agentExecutor.maxReplicas | int | `5` |  |
| autoscaling.agentExecutor.minReplicas | int | `1` |  |
| autoscaling.agentExecutor.queueTypes | string | `""` |  |
| autoscaling.agentExecutor.targetQueueSize | int | `5` |  |
| autoscaling.agentWorker.enabled | bool | `true` |  |
| autoscaling.agentWorker.maxReplicas | int | `5` |  |
| autoscaling.agentWorker.minReplicas | int | `1` |  |
| autoscaling.agentWorker.queueTypes | string | `""` |  |
| autoscaling.agentWorker.targetQueueSize | int | `5` |  |
| autoscaling.executor.enabled | bool | `true` |  |
| autoscaling.executor.maxReplicas | int | `10` |  |
| autoscaling.executor.minReplicas | int | `1` |  |
| autoscaling.executor.queueTypes | string | `""` |  |
| autoscaling.executor.targetQueueSize | int | `5` |  |
| autoscaling.worker.enabled | bool | `true` |  |
| autoscaling.worker.maxReplicas | int | `10` |  |
| autoscaling.worker.minReplicas | int | `1` |  |
| autoscaling.worker.queueTypes | string | `""` |  |
| autoscaling.worker.targetQueueSize | int | `5` |  |
| bridgeSecrets.coreSecretName | string | `"tracecat-secrets"` |  |
| bridgeSecrets.enabled | bool | `true` |  |
| bridgeSecrets.redisPort | int | `6379` |  |
| bridgeSecrets.redisSecretName | string | `"tracecat-redis-url"` |  |
| bridgeSecrets.redisServiceName | string | `""` |  |
| bridgeSecrets.retain | bool | `true` |  |
| bridgeSecrets.s3SecretName | string | `"tracecat-s3"` |  |
| cnpg.app.database | string | `"tracecat"` |  |
| cnpg.app.imageName | string | `"ghcr.io/cloudnative-pg/postgresql:17.4"` |  |
| cnpg.app.instances | int | `1` |  |
| cnpg.app.name | string | `"tracecat-pg-app"` |  |
| cnpg.app.owner | string | `"tracecat"` |  |
| cnpg.app.resources.limits.memory | string | `"1Gi"` |  |
| cnpg.app.resources.requests.cpu | string | `"250m"` |  |
| cnpg.app.resources.requests.memory | string | `"512Mi"` |  |
| cnpg.app.storage.size | string | `"5Gi"` |  |
| cnpg.app.storage.storageClass | string | `""` |  |
| cnpg.backup.destinationPath | string | `"s3://tracecat-pg-backups"` |  |
| cnpg.backup.enabled | bool | `false` |  |
| cnpg.backup.endpointURL | string | `""` |  |
| cnpg.backup.retentionPolicy | string | `"30d"` |  |
| cnpg.backup.s3Credentials.accessKeyIdKey | string | `"accessKeyId"` |  |
| cnpg.backup.s3Credentials.secretAccessKeyKey | string | `"secretAccessKey"` |  |
| cnpg.backup.s3Credentials.secretName | string | `"tracecat-s3"` |  |
| cnpg.backup.scheduledBackup.enabled | bool | `true` |  |
| cnpg.backup.scheduledBackup.immediate | bool | `true` |  |
| cnpg.backup.scheduledBackup.schedule | string | `"0 0 3 * * *"` |  |
| cnpg.backup.walCompression | string | `"gzip"` |  |
| cnpg.enablePodAntiAffinity | bool | `true` |  |
| cnpg.enabled | bool | `true` |  |
| cnpg.monitoring.enablePodMonitor | bool | `false` |  |
| cnpg.retainOnDelete | bool | `true` |  |
| cnpg.temporal.database | string | `"temporal"` |  |
| cnpg.temporal.imageName | string | `"ghcr.io/cloudnative-pg/postgresql:17.4"` |  |
| cnpg.temporal.instances | int | `1` |  |
| cnpg.temporal.name | string | `"tracecat-pg-temporal"` |  |
| cnpg.temporal.owner | string | `"temporal"` |  |
| cnpg.temporal.postInitSQL[0] | string | `"ALTER ROLE temporal CREATEDB;"` |  |
| cnpg.temporal.resources.limits.memory | string | `"1Gi"` |  |
| cnpg.temporal.resources.requests.cpu | string | `"250m"` |  |
| cnpg.temporal.resources.requests.memory | string | `"512Mi"` |  |
| cnpg.temporal.storage.size | string | `"5Gi"` |  |
| cnpg.temporal.storage.storageClass | string | `""` |  |
| commonLabels | object | `{}` |  |
| containerSecurityContext.allowPrivilegeEscalation | bool | `false` |  |
| containerSecurityContext.capabilities.drop[0] | string | `"ALL"` |  |
| containerSecurityContext.readOnlyRootFilesystem | bool | `true` |  |
| containerSecurityContext.runAsNonRoot | bool | `true` |  |
| containerSecurityContext.seccompProfile.type | string | `"RuntimeDefault"` |  |
| enterprise.featureFlags | string | `""` |  |
| enterprise.multiTenant | bool | `false` |  |
| executor.backend | string | `"ephemeral"` |  |
| executor.contextCompression.enabled | bool | `false` |  |
| executor.contextCompression.thresholdKb | int | `16` |  |
| executor.queue | string | `"shared-action-queue"` |  |
| executor.replicas | int | `4` |  |
| executor.resources.limits.cpu | string | `"4000m"` |  |
| executor.resources.limits.memory | string | `"8192Mi"` |  |
| executor.resources.requests.cpu | string | `"4000m"` |  |
| executor.resources.requests.memory | string | `"8192Mi"` |  |
| executor.serviceAccount.annotations | object | `{}` |  |
| executor.serviceAccount.create | bool | `false` |  |
| executor.serviceAccount.name | string | `""` |  |
| executor.workerPoolSize | string | `""` |  |
| externalPostgres.auth.existingSecret | string | `"tracecat-pg-app-app"` |  |
| externalPostgres.auth.username | string | `""` |  |
| externalPostgres.database | string | `"tracecat"` |  |
| externalPostgres.host | string | `"tracecat-pg-app-rw"` |  |
| externalPostgres.port | int | `5432` |  |
| externalPostgres.sslMode | string | `"require"` |  |
| externalPostgres.tls.caCert | string | `""` |  |
| externalPostgres.tls.verifyCA | bool | `false` |  |
| externalRedis.auth.existingSecret | string | `"tracecat-redis-url"` |  |
| externalS3.auth.existingSecret | string | `"tracecat-s3"` |  |
| externalS3.endpoint | string | `""` |  |
| externalS3.region | string | `"us-east-1"` |  |
| externalTemporal.auth.existingSecret | string | `nil` |  |
| externalTemporal.clusterNamespace | string | `""` |  |
| externalTemporal.clusterQueue | string | `"tracecat-task-queue"` |  |
| externalTemporal.clusterUrl | string | `""` |  |
| externalTemporal.enabled | bool | `false` |  |
| extraEnv | list | `[]` |  |
| extraEnvFrom | list | `[]` |  |
| gatewayApi.annotations | object | `{}` |  |
| gatewayApi.api.annotations | object | `{}` |  |
| gatewayApi.apiVersion | string | `"gateway.networking.k8s.io/v1"` |  |
| gatewayApi.enabled | bool | `false` |  |
| gatewayApi.hostnames | list | `[]` |  |
| gatewayApi.mcp.annotations | object | `{}` |  |
| gatewayApi.parentRefs | list | `[]` |  |
| gatewayApi.split | bool | `false` |  |
| gatewayApi.ui.annotations | object | `{}` |  |
| image.digest | string | `""` |  |
| image.pullPolicy | string | `"IfNotPresent"` |  |
| image.repository | string | `"ghcr.io/tracecathq/tracecat"` |  |
| imagePullSecrets | list | `[]` |  |
| ingress.annotations | object | `{}` |  |
| ingress.api.annotations | object | `{}` |  |
| ingress.className | string | `""` |  |
| ingress.enabled | bool | `true` |  |
| ingress.host | string | `"tracecat.example.com"` |  |
| ingress.mcp.annotations | object | `{}` |  |
| ingress.split | bool | `false` |  |
| ingress.tls | list | `[]` |  |
| ingress.ui.annotations | object | `{}` |  |
| initImage.digest | string | `""` |  |
| initImage.pullPolicy | string | `"IfNotPresent"` |  |
| initImage.repository | string | `"busybox"` |  |
| initImage.tag | string | `"1.36"` |  |
| keda.cooldownPeriod | int | `300` |  |
| keda.enabled | bool | `false` |  |
| keda.pollingInterval | int | `30` |  |
| litellm.baseUrl | string | `""` |  |
| litellm.enabled | bool | `true` |  |
| litellm.port | int | `4000` |  |
| litellm.replicas | int | `1` |  |
| litellm.resources.limits.cpu | string | `"4000m"` |  |
| litellm.resources.limits.memory | string | `"8192Mi"` |  |
| litellm.resources.requests.cpu | string | `"4000m"` |  |
| litellm.resources.requests.memory | string | `"8192Mi"` |  |
| litellm.serviceAccount.annotations | object | `{}` |  |
| litellm.serviceAccount.create | bool | `false` |  |
| litellm.serviceAccount.name | string | `""` |  |
| mcp.enabled | bool | `false` |  |
| mcp.port | int | `8099` |  |
| mcp.replicas | int | `2` |  |
| mcp.resources.limits.cpu | string | `"1000m"` |  |
| mcp.resources.limits.memory | string | `"1024Mi"` |  |
| mcp.resources.requests.cpu | string | `"1000m"` |  |
| mcp.resources.requests.memory | string | `"1024Mi"` |  |
| networkPolicy.allowExternalHttps | bool | `true` |  |
| networkPolicy.enabled | bool | `true` |  |
| networkPolicy.extraEgress | list | `[]` |  |
| networkPolicy.ingressControllerNamespaceSelector | object | `{}` |  |
| podAnnotations | object | `{}` |  |
| podDisruptionBudget.enabled | bool | `true` |  |
| podDisruptionBudget.maxUnavailable | string | `""` |  |
| podDisruptionBudget.minAvailable | int | `1` |  |
| redis.auth.enabled | bool | `false` |  |
| redis.enabled | bool | `true` |  |
| redis.persistence.enabled | bool | `true` |  |
| redis.persistence.size | string | `"2Gi"` |  |
| reloader.enabled | bool | `false` |  |
| revisionHistoryLimit | int | `3` |  |
| rustfs.config.rustfs.console_enable | string | `"false"` |  |
| rustfs.enabled | bool | `true` |  |
| rustfs.ingress.enabled | bool | `false` |  |
| rustfs.mode.distributed.enabled | bool | `false` |  |
| rustfs.mode.standalone.enabled | bool | `true` |  |
| rustfs.replicaCount | int | `1` |  |
| rustfs.secret.existingSecret | string | `"tracecat-s3"` |  |
| rustfs.storageclass.dataStorageSize | string | `"5Gi"` |  |
| rustfs.storageclass.logStorageSize | string | `"1Gi"` |  |
| rustfs.storageclass.name | string | `"local-path"` |  |
| scheduling.affinity | object | `{}` |  |
| scheduling.architecture | string | `""` |  |
| scheduling.nodeSelector | object | `{}` |  |
| scheduling.podAntiAffinity.enabled | bool | `true` |  |
| scheduling.podAntiAffinity.topologyKey | string | `"kubernetes.io/hostname"` |  |
| scheduling.tolerations | list | `[]` |  |
| scheduling.topologySpreadConstraints | list | `[]` |  |
| secrets.create.postgres.enabled | bool | `false` |  |
| secrets.create.postgres.name | string | `"tracecat-postgres-credentials"` |  |
| secrets.create.postgres.password | string | `""` |  |
| secrets.create.postgres.username | string | `""` |  |
| secrets.create.redis.enabled | bool | `false` |  |
| secrets.create.redis.name | string | `"tracecat-redis-credentials"` |  |
| secrets.create.redis.url | string | `""` |  |
| secrets.create.tracecat.dbEncryptionKey | string | `""` |  |
| secrets.create.tracecat.enabled | bool | `false` |  |
| secrets.create.tracecat.name | string | `"tracecat-secrets"` |  |
| secrets.create.tracecat.serviceKey | string | `""` |  |
| secrets.create.tracecat.signingSecret | string | `""` |  |
| secrets.create.tracecat.userAuthSecret | string | `""` |  |
| secrets.existingSecret | string | `"tracecat-secrets"` |  |
| securityContext.fsGroup | int | `1001` |  |
| securityContext.runAsGroup | int | `1001` |  |
| securityContext.runAsNonRoot | bool | `true` |  |
| securityContext.runAsUser | int | `1001` |  |
| securityContext.seccompProfile.type | string | `"RuntimeDefault"` |  |
| serviceAccount.annotations | object | `{}` |  |
| serviceAccount.automountServiceAccountToken | bool | `false` |  |
| serviceAccount.create | bool | `true` |  |
| serviceAccount.name | string | `""` |  |
| temporal.admintools.image.tag | string | `"1.31.1"` |  |
| temporal.clusterQueue | string | `"tracecat-task-queue"` |  |
| temporal.enabled | bool | `true` |  |
| temporal.schema.useHelmHooks | bool | `false` |  |
| temporal.server.config.namespaces.create | bool | `true` |  |
| temporal.server.config.namespaces.namespace[0].name | string | `"default"` |  |
| temporal.server.config.namespaces.namespace[0].retention | string | `"720h"` |  |
| temporal.server.config.persistence.datastores.default.sql.connectAddr | string | `"tracecat-pg-temporal-rw:5432"` |  |
| temporal.server.config.persistence.datastores.default.sql.connectProtocol | string | `"tcp"` |  |
| temporal.server.config.persistence.datastores.default.sql.createDatabase | bool | `true` |  |
| temporal.server.config.persistence.datastores.default.sql.databaseName | string | `"temporal"` |  |
| temporal.server.config.persistence.datastores.default.sql.existingSecret | string | `"tracecat-pg-temporal-app"` |  |
| temporal.server.config.persistence.datastores.default.sql.manageSchema | bool | `true` |  |
| temporal.server.config.persistence.datastores.default.sql.maxConns | int | `20` |  |
| temporal.server.config.persistence.datastores.default.sql.maxIdleConns | int | `10` |  |
| temporal.server.config.persistence.datastores.default.sql.pluginName | string | `"postgres12_pgx"` |  |
| temporal.server.config.persistence.datastores.default.sql.secretKey | string | `"password"` |  |
| temporal.server.config.persistence.datastores.default.sql.user | string | `"temporal"` |  |
| temporal.server.config.persistence.datastores.visibility.sql.connectAddr | string | `"tracecat-pg-temporal-rw:5432"` |  |
| temporal.server.config.persistence.datastores.visibility.sql.connectProtocol | string | `"tcp"` |  |
| temporal.server.config.persistence.datastores.visibility.sql.createDatabase | bool | `true` |  |
| temporal.server.config.persistence.datastores.visibility.sql.databaseName | string | `"temporal_visibility"` |  |
| temporal.server.config.persistence.datastores.visibility.sql.existingSecret | string | `"tracecat-pg-temporal-app"` |  |
| temporal.server.config.persistence.datastores.visibility.sql.manageSchema | bool | `true` |  |
| temporal.server.config.persistence.datastores.visibility.sql.maxConns | int | `20` |  |
| temporal.server.config.persistence.datastores.visibility.sql.maxIdleConns | int | `10` |  |
| temporal.server.config.persistence.datastores.visibility.sql.pluginName | string | `"postgres12_pgx"` |  |
| temporal.server.config.persistence.datastores.visibility.sql.secretKey | string | `"password"` |  |
| temporal.server.config.persistence.datastores.visibility.sql.user | string | `"temporal"` |  |
| temporal.server.config.persistence.defaultStore | string | `"default"` |  |
| temporal.server.config.persistence.numHistoryShards | int | `512` |  |
| temporal.server.config.persistence.visibilityStore | string | `"visibility"` |  |
| temporal.server.image.tag | string | `"1.31.1"` |  |
| temporal.server.replicaCount | int | `1` |  |
| temporal.web.additionalEnvSecretName | string | `""` |  |
| temporal.web.enabled | bool | `false` |  |
| temporal.web.image.tag | string | `"2.51.0"` |  |
| tracecat.agentFs.archiveCacheMaxBytes | string | `""` |  |
| tracecat.allowOrigins | string | `""` |  |
| tracecat.appEnv | string | `"production"` |  |
| tracecat.auth.allowedDomains | string | `""` |  |
| tracecat.auth.minPasswordLength | int | `16` |  |
| tracecat.auth.superadminEmail | string | `""` |  |
| tracecat.auth.types | string | `"basic"` |  |
| tracecat.blobStorage.buckets.agent | string | `""` |  |
| tracecat.blobStorage.buckets.attachments | string | `""` |  |
| tracecat.blobStorage.buckets.registry | string | `""` |  |
| tracecat.blobStorage.buckets.workflow | string | `""` |  |
| tracecat.blobStorage.endpoint | string | `""` |  |
| tracecat.blobStorage.maxAttempts | string | `""` |  |
| tracecat.executorTokenTtlSeconds | string | `""` |  |
| tracecat.externalization.collectionManifestsEnabled | string | `""` |  |
| tracecat.externalization.resultEnabled | string | `""` |  |
| tracecat.externalization.resultThresholdBytes | string | `""` |  |
| tracecat.localRepository.enabled | string | `""` |  |
| tracecat.localRepository.path | string | `""` |  |
| tracecat.logLevel | string | `"INFO"` |  |
| tracecat.mcp.fileTransferUrlExpirySeconds | int | `300` |  |
| tracecat.mcp.maxInputSizeBytes | int | `524288` |  |
| tracecat.mcp.rateLimitBurst | int | `10` |  |
| tracecat.mcp.rateLimitRps | float | `2` |  |
| tracecat.mcp.startupMaxAttempts | int | `3` |  |
| tracecat.mcp.startupRetryDelaySeconds | int | `2` |  |
| tracecat.mcp.toolTimeoutSeconds | int | `120` |  |
| tracecat.oauth.clientId | string | `""` |  |
| tracecat.oauth.clientSecret | string | `""` |  |
| tracecat.oauth.existingSecret | string | `""` |  |
| tracecat.oauth.existingSecretKey | string | `"clientSecret"` |  |
| tracecat.oidc.clientId | string | `""` |  |
| tracecat.oidc.clientSecret | string | `""` |  |
| tracecat.oidc.existingSecret | string | `""` |  |
| tracecat.oidc.existingSecretKey | string | `"clientSecret"` |  |
| tracecat.oidc.issuer | string | `""` |  |
| tracecat.oidc.scopes | string | `""` |  |
| tracecat.registrySync.builtinUseInstalledSitePackages | bool | `true` |  |
| tracecat.saml.acceptedTimeDiff | string | `""` |  |
| tracecat.saml.allowUnsolicited | string | `"false"` |  |
| tracecat.saml.authnRequestsSigned | string | `"false"` |  |
| tracecat.saml.caCerts | string | `""` |  |
| tracecat.saml.enabled | bool | `false` |  |
| tracecat.saml.idpMetadataUrl | string | `""` |  |
| tracecat.saml.publicAcsUrl | string | `""` |  |
| tracecat.saml.verifySslEntity | string | `"true"` |  |
| tracecat.saml.verifySslMetadata | string | `"true"` |  |
| tracecat.sandbox.disableNsjail | bool | `true` |  |
| tracecat.sentryDsn | string | `""` |  |
| tracecat.temporal.adminToolsImage | string | `"temporalio/admin-tools:1.31.1"` |  |
| tracecat.temporal.metrics.enabled | bool | `false` |  |
| tracecat.temporal.metrics.path | string | `"/metrics"` |  |
| tracecat.temporal.metrics.port | int | `9000` |  |
| tracecat.temporal.metrics.scrape | bool | `true` |  |
| tracecat.temporal.metrics.serviceMonitor.additionalLabels | object | `{}` |  |
| tracecat.temporal.metrics.serviceMonitor.enabled | bool | `false` |  |
| tracecat.temporal.metrics.serviceMonitor.interval | string | `"30s"` |  |
| tracecat.temporal.metrics.serviceMonitor.scrapeTimeout | string | `""` |  |
| tracecat.temporal.searchAttributes.TracecatAlias | string | `"Keyword"` |  |
| tracecat.temporal.searchAttributes.TracecatExecutionType | string | `"Keyword"` |  |
| tracecat.temporal.searchAttributes.TracecatTriggerType | string | `"Keyword"` |  |
| tracecat.temporal.searchAttributes.TracecatTriggeredByUserId | string | `"Keyword"` |  |
| tracecat.temporal.searchAttributes.TracecatWorkspaceId | string | `"Keyword"` |  |
| tracecat.workflowArtifactRetentionDays | string | `""` |  |
| ui.replicas | int | `1` |  |
| ui.resources.limits.cpu | string | `"500m"` |  |
| ui.resources.limits.memory | string | `"1024Mi"` |  |
| ui.resources.requests.cpu | string | `"500m"` |  |
| ui.resources.requests.memory | string | `"512Mi"` |  |
| uiImage.digest | string | `""` |  |
| uiImage.pullPolicy | string | `"IfNotPresent"` |  |
| uiImage.repository | string | `"ghcr.io/tracecathq/tracecat-ui"` |  |
| urls.publicApi | string | `""` |  |
| urls.publicApp | string | `""` |  |
| urls.publicMcp | string | `""` |  |
| urls.publicS3 | string | `""` |  |
| virtualService.apiVersion | string | `"networking.istio.io/v1beta1"` |  |
| virtualService.enabled | bool | `false` |  |
| virtualService.temporal.configs | list | `[]` |  |
| virtualService.temporal.enabled | bool | `false` |  |
| virtualService.tracecat.configs | list | `[]` |  |
| virtualService.tracecat.enabled | bool | `true` |  |
| virtualService.webhooks.configs | list | `[]` |  |
| virtualService.webhooks.enabled | bool | `false` |  |
| virtualService.webhooks.timeout | string | `"5s"` |  |
| worker.contextCompression.enabled | bool | `false` |  |
| worker.contextCompression.thresholdKb | int | `16` |  |
| worker.replicas | int | `4` |  |
| worker.resources.limits.cpu | string | `"2000m"` |  |
| worker.resources.limits.memory | string | `"2048Mi"` |  |
| worker.resources.requests.cpu | string | `"2000m"` |  |
| worker.resources.requests.memory | string | `"2048Mi"` |  |

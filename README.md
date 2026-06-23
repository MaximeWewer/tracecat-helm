# Tracecat Helm Chart

Helm chart for [Tracecat](https://github.com/TracecatHQ/tracecat) on Kubernetes.

## Features

- Full Tracecat topology: API, UI, Temporal workers (dsl / executor / agent / agent-executor), LiteLLM gateway, MCP server
- Temporal via the official subchart, backed by PostgreSQL
- PostgreSQL via the [CloudNative-PG](https://cloudnative-pg.io/) operator (app + temporal clusters)
- Redis via the [CloudPirates](https://github.com/CloudPirates-io/helm-charts) chart, S3 via [RustFS](https://rustfs.com/)
- KEDA autoscaling, ServiceMonitor, NetworkPolicies, PodDisruptionBudgets
- 3 exposure modes (Ingress / Gateway API / Istio VirtualService)
- Hardened: rootless, read-only rootfs, dropped caps, generate-once secrets
- Automated weekly version updates tracking upstream Tracecat releases

## Prerequisites

- Kubernetes **1.25+**, Helm **3+**.
- **CloudNative-PG operator** installed cluster-wide (this chart ships only the `Cluster` CRs):
  ```sh
  helm repo add cnpg https://cloudnative-pg.github.io/charts
  helm upgrade --install cnpg cnpg/cloudnative-pg -n cnpg-system --create-namespace
  ```
- Optional: KEDA (autoscaling), Prometheus Operator CRDs (ServiceMonitor/PodMonitor), Gateway API CRDs.

## Installation

### Helm (OCI)

```bash
helm install tracecat oci://ghcr.io/maximewewer/charts/tracecat \
  --namespace tracecat --create-namespace \
  --set tracecat.auth.superadminEmail=admin@example.com
```

### From source

```bash
git clone https://github.com/MaximeWewer/tracecat-helm.git
cd tracecat-helm
helm dependency build chart/
helm install tracecat chart/ \
  --namespace tracecat --create-namespace \
  --set tracecat.auth.superadminEmail=admin@example.com
```

### Argo CD

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: tracecat
  namespace: argocd
spec:
  project: default
  source:
    repoURL: ghcr.io/maximewewer/charts
    chart: tracecat
    targetRevision: "<chart-version>"   # pin a published version
    helm:
      values: |
        tracecat:
          auth:
            superadminEmail: admin@example.com
  destination:
    server: https://kubernetes.default.svc
    namespace: tracecat
  syncPolicy:
    automated: { prune: true, selfHeal: true }
    syncOptions: [CreateNamespace=true]
```

Secrets are generated automatically (see `bridgeSecrets`). On first sign-in, register the superadmin email to claim the admin account.

## Configuration

See the full list of configurable values in [`chart/README.md`](chart/README.md).

## License

This chart is distributed under the [Apache License 2.0](LICENSE). Tracecat itself is licensed by TracecatHQ.

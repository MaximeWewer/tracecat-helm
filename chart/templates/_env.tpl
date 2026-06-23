{{/*
Environment variable assembly (per component) for the Tracecat chart.
This file is loaded by Helm alongside the other templates/*.tpl files.
*/}}

{{/*
Common environment variables shared across all backend services
(api, worker, executor)
*/}}
{{- define "tracecat.featureFlags" -}}
{{- $flags := list -}}
{{- if .Values.enterprise.featureFlags }}
{{- $flags = append $flags .Values.enterprise.featureFlags -}}
{{- end }}
{{- join "," $flags -}}
{{- end }}

{{- define "tracecat.env.migrations" -}}
{{- include "tracecat.env.common" . -}}
{{- end }}

{{- define "tracecat.env.common" -}}
{{- if .Values.tracecat.logLevel }}
- name: LOG_LEVEL
  value: {{ .Values.tracecat.logLevel | quote }}
{{- end }}
- name: TRACECAT__APP_ENV
  value: {{ .Values.tracecat.appEnv | quote }}
- name: TRACECAT__FEATURE_FLAGS
  value: {{ include "tracecat.featureFlags" . | quote }}
- name: TRACECAT__EE_MULTI_TENANT
  value: {{ .Values.enterprise.multiTenant | quote }}
{{- if .Values.tracecat.executorTokenTtlSeconds }}
- name: TRACECAT__EXECUTOR_TOKEN_TTL_SECONDS
  value: {{ .Values.tracecat.executorTokenTtlSeconds | quote }}
{{- end }}
{{- if .Values.tracecat.workflowArtifactRetentionDays }}
- name: TRACECAT__WORKFLOW_ARTIFACT_RETENTION_DAYS
  value: {{ .Values.tracecat.workflowArtifactRetentionDays | quote }}
{{- end }}
{{- if ne (toString .Values.tracecat.externalization.resultEnabled) "" }}
- name: TRACECAT__RESULT_EXTERNALIZATION_ENABLED
  value: {{ .Values.tracecat.externalization.resultEnabled | quote }}
{{- end }}
{{- if .Values.tracecat.externalization.resultThresholdBytes }}
- name: TRACECAT__RESULT_EXTERNALIZATION_THRESHOLD_BYTES
  value: {{ .Values.tracecat.externalization.resultThresholdBytes | quote }}
{{- end }}
{{- if ne (toString .Values.tracecat.externalization.collectionManifestsEnabled) "" }}
- name: TRACECAT__COLLECTION_MANIFESTS_ENABLED
  value: {{ .Values.tracecat.externalization.collectionManifestsEnabled | quote }}
{{- end }}
{{- if .Values.tracecat.agentFs.archiveCacheMaxBytes }}
- name: TRACECAT__AGENT_FS_ARCHIVE_CACHE_MAX_BYTES
  value: {{ .Values.tracecat.agentFs.archiveCacheMaxBytes | quote }}
{{- end }}
{{- if ne (toString .Values.tracecat.localRepository.enabled) "" }}
- name: TRACECAT__LOCAL_REPOSITORY_ENABLED
  value: {{ .Values.tracecat.localRepository.enabled | quote }}
{{- end }}
{{- if .Values.tracecat.localRepository.path }}
- name: TRACECAT__LOCAL_REPOSITORY_PATH
  value: {{ .Values.tracecat.localRepository.path | quote }}
{{- end }}
{{- include "tracecat.extraEnv" . }}
{{- end }}

{{/*
Temporal environment variables (shared by api, worker, executor)
*/}}
{{- define "tracecat.env.temporal" -}}
- name: TEMPORAL__CLUSTER_URL
  value: {{ include "tracecat.temporalClusterUrl" . | quote }}
- name: TEMPORAL__CLUSTER_NAMESPACE
  value: {{ include "tracecat.temporalNamespace" . | quote }}
- name: TEMPORAL__CLUSTER_QUEUE
  value: {{ include "tracecat.temporalQueue" . | quote }}
{{- if .Values.externalTemporal.enabled }}
{{- if .Values.externalTemporal.auth.existingSecret }}
- name: TEMPORAL__API_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .Values.externalTemporal.auth.existingSecret }}
      key: apiKey
{{- end }}
{{- end }}
{{- end }}

{{/*
Blob storage environment variables
*/}}
{{- define "tracecat.env.blobStorage" -}}
{{- $endpoint := include "tracecat.blobStorageEndpoint" . }}
{{- if $endpoint }}
- name: TRACECAT__BLOB_STORAGE_ENDPOINT
  value: {{ $endpoint | quote }}
{{- end }}
{{- if .Values.tracecat.blobStorage.buckets.attachments }}
- name: TRACECAT__BLOB_STORAGE_BUCKET_ATTACHMENTS
  value: {{ .Values.tracecat.blobStorage.buckets.attachments | quote }}
{{- end }}
{{- if .Values.tracecat.blobStorage.buckets.registry }}
- name: TRACECAT__BLOB_STORAGE_BUCKET_REGISTRY
  value: {{ .Values.tracecat.blobStorage.buckets.registry | quote }}
{{- end }}
{{- if .Values.tracecat.blobStorage.buckets.workflow }}
- name: TRACECAT__BLOB_STORAGE_BUCKET_WORKFLOW
  value: {{ .Values.tracecat.blobStorage.buckets.workflow | quote }}
{{- end }}
{{- if .Values.tracecat.blobStorage.buckets.agent }}
- name: TRACECAT__BLOB_STORAGE_BUCKET_AGENT
  value: {{ .Values.tracecat.blobStorage.buckets.agent | quote }}
{{- end }}
{{- if .Values.tracecat.blobStorage.maxAttempts }}
- name: TRACECAT__BLOB_STORAGE_MAX_ATTEMPTS
  value: {{ .Values.tracecat.blobStorage.maxAttempts | quote }}
{{- end }}
{{- if .Values.externalS3.region }}
- name: AWS_REGION
  value: {{ .Values.externalS3.region | quote }}
- name: AWS_DEFAULT_REGION
  value: {{ .Values.externalS3.region | quote }}
{{- end }}
{{- if .Values.externalS3.auth.existingSecret }}
- name: AWS_ACCESS_KEY_ID
  valueFrom:
    secretKeyRef:
      name: {{ .Values.externalS3.auth.existingSecret }}
      key: accessKeyId
- name: AWS_SECRET_ACCESS_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .Values.externalS3.auth.existingSecret }}
      key: secretAccessKey
{{- end }}
{{- end }}

{{/*
PostgreSQL environment variables
Builds discrete TRACECAT__DB_* from computed host/port/database/sslmode + secret creds.
*/}}
{{- define "tracecat.env.postgres" -}}
{{- $host := include "tracecat.postgres.host" . }}
{{- $port := include "tracecat.postgres.port" . }}
{{- $database := include "tracecat.postgres.database" . }}
{{- $verifyCA := and .Values.externalPostgres.tls.verifyCA (include "tracecat.postgres.caConfigMapName" .) }}
{{- $sslMode := ternary "verify-full" (include "tracecat.postgres.sslMode" .) (not (empty $verifyCA)) }}
{{- $postgresSecretName := include "tracecat.secrets.postgresName" . }}
{{- if not $postgresSecretName }}
{{- fail "externalPostgres.auth.existingSecret or secrets.create.postgres.enabled is required" }}
{{- end }}
- name: TRACECAT__DB_USER
  valueFrom:
    secretKeyRef:
      name: {{ $postgresSecretName }}
      key: username
- name: TRACECAT__DB_PASS
  valueFrom:
    secretKeyRef:
      name: {{ $postgresSecretName }}
      key: password
- name: TRACECAT__DB_ENDPOINT
  value: {{ $host | quote }}
- name: TRACECAT__DB_PORT
  value: {{ $port | quote }}
- name: TRACECAT__DB_NAME
  value: {{ $database | quote }}
- name: TRACECAT__DB_SSLMODE
  value: {{ $sslMode | quote }}
{{- if $verifyCA }}
# libpq-style root cert path; honored by psycopg (migrations) and asyncpg.
- name: PGSSLROOTCERT
  value: {{ include "tracecat.postgres.caCertPath" . | quote }}
- name: PGSSLMODE
  value: {{ $sslMode | quote }}
{{- end }}
{{- end }}

{{/*
Redis environment variables
Constructs REDIS_URL from computed host/port or from external secret
*/}}
{{- define "tracecat.env.redis" -}}
{{- $redisSecretName := include "tracecat.secrets.redisName" . }}
{{- if $redisSecretName }}
- name: REDIS_URL
  valueFrom:
    secretKeyRef:
      name: {{ $redisSecretName }}
      key: url
{{- else }}
{{- fail "externalRedis.auth.existingSecret or secrets.create.redis.enabled is required" }}
{{- end }}
{{- end }}

{{/*
Sandbox environment variables (shared by executor + agent executor)
*/}}
{{- define "tracecat.env.sandbox" -}}
- name: TRACECAT__DISABLE_NSJAIL
  value: {{ .Values.tracecat.sandbox.disableNsjail | quote }}
- name: TRACECAT__SANDBOX_NSJAIL_PATH
  value: "/usr/local/bin/nsjail"
- name: TRACECAT__SANDBOX_ROOTFS_PATH
  value: "/var/lib/tracecat/sandbox-rootfs"
- name: TRACECAT__SANDBOX_CACHE_DIR
  value: "/var/lib/tracecat/sandbox-cache"
- name: TRACECAT__UNSAFE_DISABLE_SM_MASKING
  value: "false"
{{- end }}

{{/*
API service environment variables
Merges: common + temporal + postgres + redis + api-specific
*/}}
{{- define "tracecat.env.api" -}}
{{ include "tracecat.env.common" . }}
{{ include "tracecat.env.temporal" . }}
{{ include "tracecat.env.blobStorage" . }}
{{ include "tracecat.env.postgres" . }}
{{ include "tracecat.env.redis" . }}
- name: TRACECAT__API_ROOT_PATH
  value: "/api"
- name: TRACECAT__API_URL
  value: {{ include "tracecat.internalApiUrl" . | quote }}
- name: TRACECAT__PUBLIC_APP_URL
  value: {{ include "tracecat.publicAppUrl" . | quote }}
- name: TRACECAT__PUBLIC_API_URL
  value: {{ include "tracecat.publicApiUrl" . | quote }}
{{- $publicS3Url := include "tracecat.publicS3Url" . }}
{{- if $publicS3Url }}
- name: TRACECAT__BLOB_STORAGE_PRESIGNED_URL_ENDPOINT
  value: {{ $publicS3Url | quote }}
{{- end }}
- name: TRACECAT__ALLOW_ORIGINS
  value: {{ .Values.tracecat.allowOrigins | quote }}
- name: TRACECAT__REGISTRY_SYNC_BUILTIN_USE_INSTALLED_SITE_PACKAGES
  value: {{ .Values.tracecat.registrySync.builtinUseInstalledSitePackages | quote }}
{{- /* Auth settings */}}
- name: TRACECAT__AUTH_TYPES
  value: {{ .Values.tracecat.auth.types | quote }}
- name: TRACECAT__AUTH_ALLOWED_DOMAINS
  value: {{ .Values.tracecat.auth.allowedDomains | quote }}
- name: TRACECAT__AUTH_MIN_PASSWORD_LENGTH
  value: {{ .Values.tracecat.auth.minPasswordLength | quote }}
- name: TRACECAT__AUTH_SUPERADMIN_EMAIL
  value: {{ .Values.tracecat.auth.superadminEmail | quote }}
{{- /* Google OAuth (auth.types includes "google_oauth") */}}
{{- if .Values.tracecat.oauth.clientId }}
- name: OAUTH_CLIENT_ID
  value: {{ .Values.tracecat.oauth.clientId | quote }}
{{- end }}
{{- if .Values.tracecat.oauth.existingSecret }}
- name: OAUTH_CLIENT_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ .Values.tracecat.oauth.existingSecret }}
      key: {{ .Values.tracecat.oauth.existingSecretKey }}
{{- else if .Values.tracecat.oauth.clientSecret }}
- name: OAUTH_CLIENT_SECRET
  value: {{ .Values.tracecat.oauth.clientSecret | quote }}
{{- end }}
{{- /* SAML settings */}}
{{- if .Values.tracecat.saml.enabled }}
- name: SAML_IDP_METADATA_URL
  value: {{ .Values.tracecat.saml.idpMetadataUrl | quote }}
{{- if .Values.tracecat.saml.publicAcsUrl }}
- name: SAML_PUBLIC_ACS_URL
  value: {{ .Values.tracecat.saml.publicAcsUrl | quote }}
{{- end }}
- name: SAML_ALLOW_UNSOLICITED
  value: {{ .Values.tracecat.saml.allowUnsolicited | quote }}
- name: SAML_AUTHN_REQUESTS_SIGNED
  value: {{ .Values.tracecat.saml.authnRequestsSigned | quote }}
- name: SAML_VERIFY_SSL_ENTITY
  value: {{ .Values.tracecat.saml.verifySslEntity | quote }}
- name: SAML_VERIFY_SSL_METADATA
  value: {{ .Values.tracecat.saml.verifySslMetadata | quote }}
{{- if .Values.tracecat.saml.acceptedTimeDiff }}
- name: SAML_ACCEPTED_TIME_DIFF
  value: {{ .Values.tracecat.saml.acceptedTimeDiff | quote }}
{{- end }}
{{- if .Values.tracecat.saml.caCerts }}
- name: SAML_CA_CERTS
  value: {{ .Values.tracecat.saml.caCerts | quote }}
{{- end }}
{{- end }}
{{- /* OIDC settings (API only needs these when oidc auth is enabled) */}}
{{- if regexMatch "(^|,)\\s*oidc\\s*(,|$)" (.Values.tracecat.auth.types | default "") }}
{{- if .Values.tracecat.oidc.issuer }}
- name: OIDC_ISSUER
  value: {{ .Values.tracecat.oidc.issuer | quote }}
{{- end }}
{{- if .Values.tracecat.oidc.clientId }}
- name: OIDC_CLIENT_ID
  value: {{ .Values.tracecat.oidc.clientId | quote }}
{{- end }}
{{- if .Values.tracecat.oidc.existingSecret }}
- name: OIDC_CLIENT_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ .Values.tracecat.oidc.existingSecret }}
      key: {{ .Values.tracecat.oidc.existingSecretKey }}
{{- else if .Values.tracecat.oidc.clientSecret }}
- name: OIDC_CLIENT_SECRET
  value: {{ .Values.tracecat.oidc.clientSecret | quote }}
{{- end }}
{{- if .Values.tracecat.oidc.scopes }}
- name: OIDC_SCOPES
  value: {{ .Values.tracecat.oidc.scopes | quote }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Worker service environment variables
Merges: common + temporal + postgres + redis + worker-specific
*/}}
{{- define "tracecat.env.worker" -}}
{{ include "tracecat.env.common" . }}
{{ include "tracecat.env.temporal" . }}
{{ include "tracecat.env.blobStorage" . }}
{{ include "tracecat.env.postgres" . }}
{{ include "tracecat.env.redis" . }}
{{- if .Values.tracecat.temporal.metrics.enabled }}
- name: TEMPORAL__METRICS_PORT
  value: {{ .Values.tracecat.temporal.metrics.port | quote }}
{{- end }}
- name: TRACECAT__API_ROOT_PATH
  value: "/api"
- name: TRACECAT__API_URL
  value: {{ include "tracecat.internalApiUrl" . | quote }}
- name: TRACECAT__PUBLIC_API_URL
  value: {{ include "tracecat.publicApiUrl" . | quote }}
{{- /* Context compression */}}
- name: TRACECAT__CONTEXT_COMPRESSION_ENABLED
  value: {{ .Values.worker.contextCompression.enabled | quote }}
- name: TRACECAT__CONTEXT_COMPRESSION_THRESHOLD_KB
  value: {{ .Values.worker.contextCompression.thresholdKb | quote }}
{{- /* Sentry */}}
{{- if .Values.tracecat.sentryDsn }}
- name: SENTRY_DSN
  value: {{ .Values.tracecat.sentryDsn | quote }}
{{- end }}
{{- end }}

{{/*
Executor service environment variables
Merges: common + temporal + postgres + redis + executor-specific
*/}}
{{- define "tracecat.env.executor" -}}
{{ include "tracecat.env.common" . }}
{{ include "tracecat.env.temporal" . }}
{{ include "tracecat.env.blobStorage" . }}
{{ include "tracecat.env.postgres" . }}
{{ include "tracecat.env.redis" . }}
{{- if .Values.tracecat.temporal.metrics.enabled }}
- name: TEMPORAL__METRICS_PORT
  value: {{ .Values.tracecat.temporal.metrics.port | quote }}
{{- end }}
- name: TRACECAT__API_URL
  value: {{ include "tracecat.internalApiUrl" . | quote }}
{{- /* Context compression */}}
- name: TRACECAT__CONTEXT_COMPRESSION_ENABLED
  value: {{ .Values.executor.contextCompression.enabled | quote }}
- name: TRACECAT__CONTEXT_COMPRESSION_THRESHOLD_KB
  value: {{ .Values.executor.contextCompression.thresholdKb | quote }}
{{- /* Sandbox + secret masking */}}
{{ include "tracecat.env.sandbox" . }}
{{- /* Executor settings */}}
- name: TRACECAT__EXECUTOR_BACKEND
  value: {{ .Values.executor.backend | quote }}
- name: TRACECAT__EXECUTOR_QUEUE
  value: {{ .Values.executor.queue | quote }}
- name: TRACECAT__EXECUTOR_WORKER_POOL_SIZE
  value: {{ .Values.executor.workerPoolSize | quote }}
{{- end }}

{{/*
Agent Worker service environment variables (python -m tracecat.agent.worker)
Temporal worker polling the agent queue; routes LLM calls via litellm.
Merges: common + temporal + blobStorage + postgres + redis + agent-worker-specific
*/}}
{{- define "tracecat.env.agentWorker" -}}
{{ include "tracecat.env.common" . }}
{{ include "tracecat.env.temporal" . }}
{{ include "tracecat.env.blobStorage" . }}
{{ include "tracecat.env.postgres" . }}
{{ include "tracecat.env.redis" . }}
{{- if .Values.tracecat.temporal.metrics.enabled }}
- name: TEMPORAL__METRICS_PORT
  value: {{ .Values.tracecat.temporal.metrics.port | quote }}
{{- end }}
- name: TRACECAT__API_URL
  value: {{ include "tracecat.internalApiUrl" . | quote }}
- name: TRACECAT__LITELLM_BASE_URL
  value: {{ include "tracecat.litellmBaseUrl" . | quote }}
{{- /* Queues */}}
- name: TRACECAT__AGENT_QUEUE
  value: {{ .Values.agentWorker.queue | quote }}
- name: TRACECAT__AGENT_EXECUTOR_QUEUE
  value: {{ .Values.agentExecutor.queue | quote }}
- name: TRACECAT__EXECUTOR_QUEUE
  value: {{ .Values.executor.queue | quote }}
- name: TRACECAT__EXECUTOR_CLIENT_TIMEOUT
  value: {{ .Values.agentWorker.executorClientTimeout | quote }}
{{- /* Context compression */}}
- name: TRACECAT__CONTEXT_COMPRESSION_ENABLED
  value: {{ .Values.agentWorker.contextCompression.enabled | quote }}
- name: TRACECAT__CONTEXT_COMPRESSION_THRESHOLD_KB
  value: {{ .Values.agentWorker.contextCompression.thresholdKb | quote }}
{{- end }}

{{/*
Agent Executor service environment variables (python -m tracecat.agent.executor_worker)
Sandboxed activity executor for agent actions; talks to litellm.
Merges: common + temporal + blobStorage + postgres + redis + sandbox + agent-executor-specific
*/}}
{{- define "tracecat.env.agentExecutor" -}}
{{ include "tracecat.env.common" . }}
{{ include "tracecat.env.temporal" . }}
{{ include "tracecat.env.blobStorage" . }}
{{ include "tracecat.env.postgres" . }}
{{ include "tracecat.env.redis" . }}
{{- if .Values.tracecat.temporal.metrics.enabled }}
- name: TEMPORAL__METRICS_PORT
  value: {{ .Values.tracecat.temporal.metrics.port | quote }}
{{- end }}
- name: TRACECAT__API_URL
  value: {{ include "tracecat.internalApiUrl" . | quote }}
- name: TRACECAT__LITELLM_BASE_URL
  value: {{ include "tracecat.litellmBaseUrl" . | quote }}
{{- /* Context compression */}}
- name: TRACECAT__CONTEXT_COMPRESSION_ENABLED
  value: {{ .Values.agentExecutor.contextCompression.enabled | quote }}
- name: TRACECAT__CONTEXT_COMPRESSION_THRESHOLD_KB
  value: {{ .Values.agentExecutor.contextCompression.thresholdKb | quote }}
{{- /* Sandbox + secret masking */}}
{{ include "tracecat.env.sandbox" . }}
{{- /* Queues */}}
- name: TRACECAT__AGENT_QUEUE
  value: {{ .Values.agentWorker.queue | quote }}
- name: TRACECAT__AGENT_EXECUTOR_QUEUE
  value: {{ .Values.agentExecutor.queue | quote }}
- name: TRACECAT__EXECUTOR_QUEUE
  value: {{ .Values.executor.queue | quote }}
{{- /* Agent executor settings */}}
- name: TRACECAT__EXECUTOR_BACKEND
  value: {{ .Values.agentExecutor.backend | quote }}
- name: TRACECAT__EXECUTOR_WORKER_POOL_SIZE
  value: {{ .Values.agentExecutor.workerPoolSize | quote }}
- name: TRACECAT__AGENT_EXECUTOR_MAX_CONCURRENT_ACTIVITIES
  value: {{ .Values.agentExecutor.maxConcurrentActivities | quote }}
- name: TRACECAT__LLM_PROXY_READ_TIMEOUT
  value: {{ .Values.agentExecutor.llmProxyReadTimeout | quote }}
- name: TRACECAT__LLM_GATEWAY_CREDENTIAL_CACHE_TTL_SECONDS
  value: {{ .Values.agentExecutor.llmGateway.credentialCacheTtlSeconds | quote }}
- name: TRACECAT__LLM_GATEWAY_HEALTHCHECK_INTERVAL_SECONDS
  value: {{ .Values.agentExecutor.llmGateway.healthcheckIntervalSeconds | quote }}
{{- end }}

{{/*
LiteLLM proxy environment variables (python -m tracecat.agent.litellm)
Needs DB + encryption/service keys; serves the unified LLM gateway on :4000.
Merges: common + postgres + core secrets + litellm-specific
*/}}
{{- define "tracecat.env.litellm" -}}
{{ include "tracecat.env.common" . }}
{{ include "tracecat.env.postgres" . }}
{{ include "tracecat.env.secrets" . }}
- name: TRACECAT__LITELLM_PORT
  value: {{ .Values.litellm.port | quote }}
- name: TRACECAT__LITELLM_BASE_URL
  value: {{ include "tracecat.litellmBaseUrl" . | quote }}
{{- if .Values.bridgeSecrets.enabled }}
- name: LITELLM_MASTER_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "tracecat.secrets.coreName" . }}
      key: litellmMasterKey
{{- end }}
{{- end }}

{{/*
MCP service environment variables
Merges: common + temporal + blobStorage + postgres + redis + mcp-specific
*/}}
{{- define "tracecat.env.mcp" -}}
{{ include "tracecat.env.common" . }}
{{ include "tracecat.env.temporal" . }}
{{ include "tracecat.env.blobStorage" . }}
{{ include "tracecat.env.postgres" . }}
{{ include "tracecat.env.redis" . }}
- name: TRACECAT_MCP__HOST
  value: "0.0.0.0"
- name: TRACECAT_MCP__PORT
  value: {{ .Values.mcp.port | quote }}
- name: TRACECAT_MCP__BASE_URL
  value: {{ include "tracecat.publicMcpUrl" . | quote }}
{{- $publicS3Url := include "tracecat.publicS3Url" . }}
{{- if $publicS3Url }}
- name: TRACECAT__BLOB_STORAGE_PRESIGNED_URL_ENDPOINT
  value: {{ $publicS3Url | quote }}
{{- end }}
- name: TRACECAT_MCP__RATE_LIMIT_RPS
  value: {{ .Values.tracecat.mcp.rateLimitRps | quote }}
- name: TRACECAT_MCP__RATE_LIMIT_BURST
  value: {{ .Values.tracecat.mcp.rateLimitBurst | quote }}
- name: TRACECAT_MCP__TOOL_TIMEOUT_SECONDS
  value: {{ .Values.tracecat.mcp.toolTimeoutSeconds | quote }}
- name: TRACECAT_MCP__MAX_INPUT_SIZE_BYTES
  value: {{ .Values.tracecat.mcp.maxInputSizeBytes | quote }}
- name: TRACECAT_MCP__FILE_TRANSFER_URL_EXPIRY_SECONDS
  value: {{ .Values.tracecat.mcp.fileTransferUrlExpirySeconds | quote }}
- name: TRACECAT_MCP__STARTUP_MAX_ATTEMPTS
  value: {{ .Values.tracecat.mcp.startupMaxAttempts | quote }}
- name: TRACECAT_MCP__STARTUP_RETRY_DELAY_SECONDS
  value: {{ .Values.tracecat.mcp.startupRetryDelaySeconds | quote }}
{{- /* OIDC settings */}}
{{- if .Values.tracecat.oidc.issuer }}
- name: OIDC_ISSUER
  value: {{ .Values.tracecat.oidc.issuer | quote }}
{{- end }}
{{- if .Values.tracecat.oidc.clientId }}
- name: OIDC_CLIENT_ID
  value: {{ .Values.tracecat.oidc.clientId | quote }}
{{- end }}
{{- if .Values.tracecat.oidc.existingSecret }}
- name: OIDC_CLIENT_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ .Values.tracecat.oidc.existingSecret }}
      key: {{ .Values.tracecat.oidc.existingSecretKey }}
{{- else if .Values.tracecat.oidc.clientSecret }}
- name: OIDC_CLIENT_SECRET
  value: {{ .Values.tracecat.oidc.clientSecret | quote }}
{{- end }}
{{- if .Values.tracecat.oidc.scopes }}
- name: OIDC_SCOPES
  value: {{ .Values.tracecat.oidc.scopes | quote }}
{{- end }}
{{- end }}

{{/*
UI service environment variables
*/}}
{{- define "tracecat.env.ui" -}}
- name: NODE_ENV
  value: "production"
- name: NEXT_PUBLIC_APP_ENV
  value: {{ .Values.tracecat.appEnv | quote }}
- name: NEXT_PUBLIC_APP_URL
  value: {{ include "tracecat.publicAppUrl" . | quote }}
- name: NEXT_PUBLIC_API_URL
  value: {{ include "tracecat.publicApiUrl" . | quote }}
- name: NEXT_PUBLIC_AUTH_TYPES
  value: {{ .Values.tracecat.auth.types | quote }}
- name: NEXT_SERVER_API_URL
  value: {{ include "tracecat.internalApiUrl" . | quote }}
{{- include "tracecat.extraEnv" . }}
{{- end }}

{{/*
Secret environment variables (shared by api, worker, executor)
Uses ESO-aware secret name resolution.
*/}}
{{- define "tracecat.env.secrets" -}}
{{- $secretName := include "tracecat.secrets.coreName" . }}
- name: TRACECAT__DB_ENCRYPTION_KEY
  valueFrom:
    secretKeyRef:
      name: {{ $secretName }}
      key: dbEncryptionKey
- name: TRACECAT__SERVICE_KEY
  valueFrom:
    secretKeyRef:
      name: {{ $secretName }}
      key: serviceKey
- name: TRACECAT__SIGNING_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ $secretName }}
      key: signingSecret
{{- end -}}

{{/*
API-specific secret env vars (user auth)
Uses ESO-aware secret name resolution.
*/}}
{{- define "tracecat.env.secrets.api" -}}
{{- $coreSecretName := include "tracecat.secrets.coreName" . }}
{{ include "tracecat.env.secrets" . }}
- name: USER_AUTH_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ $coreSecretName }}
      key: userAuthSecret
{{- end -}}

{{/*
UI-specific secret env vars
Uses ESO-aware secret name resolution.
*/}}
{{- define "tracecat.env.secrets.ui" -}}
{{- $secretName := include "tracecat.secrets.coreName" . }}
- name: TRACECAT__SERVICE_KEY
  valueFrom:
    secretKeyRef:
      name: {{ $secretName }}
      key: serviceKey
{{- end -}}

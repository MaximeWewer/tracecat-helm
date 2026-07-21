{{/*
Install-time validation guards for the Tracecat chart.
This file is loaded by Helm alongside the other templates/*.tpl files.
*/}}

{{/*
Validate required core secrets are resolvable.
*/}}
{{- define "tracecat.validateRequiredSecrets" -}}
{{- $hasManualSecret := .Values.secrets.existingSecret -}}
{{- $hasTemplatedSecret := .Values.secrets.create.tracecat.enabled -}}
{{- if not (or $hasManualSecret $hasTemplatedSecret) -}}
{{- fail "Core secrets required: set secrets.existingSecret or enable secrets.create.tracecat (bridgeSecrets sets secrets.existingSecret by default)" -}}
{{- end -}}
{{- end -}}

{{/*
Validate auth config on first install
*/}}
{{- define "tracecat.validateAuthConfig" -}}
{{- if .Release.IsInstall -}}
{{- if not .Values.tracecat.auth.superadminEmail -}}
{{- fail "tracecat.auth.superadminEmail is required on first install" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Validate infrastructure dependencies
*/}}
{{- define "tracecat.validateTemporalSqlStore" -}}
{{- $storeName := .storeName -}}
{{- $storeConfig := .storeConfig -}}
{{- if not $storeConfig -}}
{{- fail (printf "temporal.server.config.persistence.datastores.%s.sql is required when temporal.enabled=true" $storeName) -}}
{{- end -}}
{{- $pluginName := dig "pluginName" "" $storeConfig -}}
{{- if and (ne $pluginName "postgres12") (ne $pluginName "postgres12_pgx") -}}
{{- fail (printf "temporal.server.config.persistence.datastores.%s.sql.pluginName must be postgres12 or postgres12_pgx" $storeName) -}}
{{- end -}}
{{- if not (dig "connectAddr" "" $storeConfig) -}}
{{- fail (printf "temporal.server.config.persistence.datastores.%s.sql.connectAddr is required when temporal.enabled=true" $storeName) -}}
{{- end -}}
{{- if not (dig "databaseName" "" $storeConfig) -}}
{{- fail (printf "temporal.server.config.persistence.datastores.%s.sql.databaseName is required when temporal.enabled=true" $storeName) -}}
{{- end -}}
{{- if not (dig "user" "" $storeConfig) -}}
{{- fail (printf "temporal.server.config.persistence.datastores.%s.sql.user is required when temporal.enabled=true" $storeName) -}}
{{- end -}}
{{- if not (or (dig "existingSecret" "" $storeConfig) (dig "password" "" $storeConfig)) -}}
{{- fail (printf "temporal.server.config.persistence.datastores.%s.sql.existingSecret (or sql.password) is required when temporal.enabled=true" $storeName) -}}
{{- end -}}
{{- end -}}

{{- define "tracecat.validateInfrastructure" -}}
{{- if and (not .Values.temporal.enabled) (not .Values.externalTemporal.enabled) -}}
{{- fail "Either temporal.enabled or externalTemporal.enabled must be true" -}}
{{- end -}}
{{- if and .Values.externalPostgres.tls.verifyCA (not .Values.externalPostgres.tls.caCert) -}}
{{- fail "externalPostgres.tls.verifyCA is true but externalPostgres.tls.caCert is empty — provide the CA PEM (or the cert is never mounted and TLS is not verified)" -}}
{{- end -}}
{{- if .Values.temporal.enabled -}}
{{- $values := .Values | toYaml | fromYaml -}}
{{- $defaultSql := dig "temporal" "server" "config" "persistence" "datastores" "default" "sql" nil $values -}}
{{- $visibilitySql := dig "temporal" "server" "config" "persistence" "datastores" "visibility" "sql" nil $values -}}
{{- include "tracecat.validateTemporalSqlStore" (dict "storeName" "default" "storeConfig" $defaultSql) -}}
{{- include "tracecat.validateTemporalSqlStore" (dict "storeName" "visibility" "storeConfig" $visibilitySql) -}}
{{- end -}}
{{- end -}}

{{/*
Fail loudly on metrics keys that moved to the top-level `metrics` section, so a
stale values.yaml silently turns metrics OFF instead of erroring.
*/}}
{{- define "tracecat.validateMetricsMigration" -}}
{{- $values := .Values | toYaml | fromYaml -}}
{{- if dig "tracecat" "temporal" "metrics" nil $values -}}
{{- fail "tracecat.temporal.metrics.* moved to metrics.tracecat.* (metrics.tracecat.enabled/port/path/scrape/components/serviceMonitor). Remove the old key." -}}
{{- end -}}
{{- if dig "cnpg" "monitoring" nil $values -}}
{{- fail "cnpg.monitoring.enablePodMonitor moved to metrics.cnpg.enabled. Remove the old key." -}}
{{- end -}}
{{- end -}}

{{/*
Validate metrics configuration.
*/}}
{{- define "tracecat.validateMetrics" -}}
{{- $values := .Values | toYaml | fromYaml -}}
{{- /*
The Redis subchart mounts a REDIS_PASSWORD secretKeyRef into the exporter when
`auth.enabled OR auth.metrics`, but only creates that Secret when auth.enabled.
The mismatch leaves the sidecar in CreateContainerConfigError.
*/ -}}
{{- if and .Values.redis.enabled (dig "redis" "metrics" "enabled" false $values) -}}
{{- if and (dig "redis" "auth" "metrics" false $values) (not (dig "redis" "auth" "enabled" false $values)) -}}
{{- fail "redis.auth.metrics=true requires redis.auth.enabled=true — otherwise the redis_exporter sidecar references a Secret the subchart never creates. Set redis.auth.metrics=false." -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Validate MCP configuration
*/}}
{{- define "tracecat.validateMcpConfig" -}}
{{- if .Values.mcp.enabled -}}
{{- if not .Values.tracecat.oidc.issuer -}}
{{- fail "tracecat.oidc.issuer is required when mcp.enabled=true" -}}
{{- end -}}
{{- if not .Values.tracecat.oidc.clientId -}}
{{- fail "tracecat.oidc.clientId is required when mcp.enabled=true" -}}
{{- end -}}
{{- if not .Values.tracecat.oidc.clientSecret -}}
{{- fail "tracecat.oidc.clientSecret is required when mcp.enabled=true" -}}
{{- end -}}
{{- end -}}
{{- end -}}

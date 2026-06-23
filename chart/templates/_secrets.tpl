{{/*
Secret name resolution & references for the Tracecat chart.
This file is loaded by Helm alongside the other templates/*.tpl files.
*/}}

{{/*
Generate secret key reference for Kubernetes secrets
Usage: {{ include "tracecat.secretKeyRef" (dict "secretName" "my-secret" "key" "password") }}
*/}}
{{- define "tracecat.secretKeyRef" -}}
valueFrom:
  secretKeyRef:
    name: {{ .secretName }}
    key: {{ .key }}
{{- end }}

{{/*
Effective core secrets name: bring-your-own existingSecret, the chart-managed
template, or the bridge-generated secret (bridgeSecrets / secrets.existingSecret).
*/}}
{{- define "tracecat.secrets.coreName" -}}
{{- if .Values.secrets.existingSecret }}
{{- .Values.secrets.existingSecret }}
{{- else if .Values.secrets.create.tracecat.enabled }}
{{- required "secrets.create.tracecat.name is required when tracecat secret template is enabled" .Values.secrets.create.tracecat.name }}
{{- else }}
{{- fail "Core secrets required: set secrets.existingSecret or enable secrets.create.tracecat (or bridgeSecrets)" }}
{{- end }}
{{- end }}

{{/*
Effective PostgreSQL secrets name for externalPostgres.
*/}}
{{- define "tracecat.secrets.postgresName" -}}
{{- if .Values.externalPostgres.auth.existingSecret }}
{{- .Values.externalPostgres.auth.existingSecret }}
{{- else if .Values.secrets.create.postgres.enabled }}
{{- required "secrets.create.postgres.name is required when postgres secret template is enabled" .Values.secrets.create.postgres.name }}
{{- end }}
{{- end }}

{{/*
Effective Redis secrets name for externalRedis.
*/}}
{{- define "tracecat.secrets.redisName" -}}
{{- if .Values.externalRedis.auth.existingSecret }}
{{- .Values.externalRedis.auth.existingSecret }}
{{- else if .Values.secrets.create.redis.enabled }}
{{- required "secrets.create.redis.name is required when redis secret template is enabled" .Values.secrets.create.redis.name }}
{{- end }}
{{- end }}

{{/*
Effective Temporal secrets name for externalTemporal.
*/}}
{{- define "tracecat.secrets.temporalName" -}}
{{- if .Values.externalTemporal.auth.existingSecret }}
{{- .Values.externalTemporal.auth.existingSecret }}
{{- end }}
{{- end }}

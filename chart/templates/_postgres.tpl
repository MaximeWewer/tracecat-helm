{{/*
PostgreSQL connection & TLS CA helpers for the Tracecat chart.
This file is loaded by Helm alongside the other templates/*.tpl files.
*/}}

{{/*
PostgreSQL Host
*/}}
{{- define "tracecat.postgres.host" -}}
{{- required "externalPostgres.host is required" .Values.externalPostgres.host }}
{{- end }}

{{/*
PostgreSQL Port
*/}}
{{- define "tracecat.postgres.port" -}}
{{- .Values.externalPostgres.port | default "5432" }}
{{- end }}

{{/*
PostgreSQL Database Name
*/}}
{{- define "tracecat.postgres.database" -}}
{{- .Values.externalPostgres.database | default "tracecat" }}
{{- end }}

{{/*
PostgreSQL SSL Mode
*/}}
{{- define "tracecat.postgres.sslMode" -}}
{{- .Values.externalPostgres.sslMode | default "prefer" }}
{{- end }}

{{/*
PostgreSQL TLS CA ConfigMap Name
Returns the name of the ConfigMap containing the CA certificate for TLS verification
*/}}
{{- define "tracecat.postgres.caConfigMapName" -}}
{{- if and .Values.externalPostgres.tls.verifyCA .Values.externalPostgres.tls.caCert }}
{{- printf "%s-postgres-ca" (include "tracecat.fullname" .) }}
{{- end }}
{{- end }}

{{/*
PostgreSQL TLS CA Certificate Path
Returns the mount path for the CA certificate file
*/}}
{{- define "tracecat.postgres.caCertPath" -}}
{{- "/etc/tracecat/certs/postgres/ca-bundle.pem" }}
{{- end }}

{{/*
PostgreSQL TLS CA Volume
Returns the volume definition for mounting the CA certificate
*/}}
{{- define "tracecat.postgres.caVolume" -}}
{{- if and .Values.externalPostgres.tls.verifyCA (include "tracecat.postgres.caConfigMapName" .) }}
- name: postgres-ca
  configMap:
    name: {{ include "tracecat.postgres.caConfigMapName" . }}
    items:
      - key: ca-bundle.pem
        path: ca-bundle.pem
{{- end }}
{{- end }}

{{/*
PostgreSQL TLS CA Volume Mount
Returns the volume mount definition for the CA certificate
*/}}
{{- define "tracecat.postgres.caVolumeMount" -}}
{{- if and .Values.externalPostgres.tls.verifyCA (include "tracecat.postgres.caConfigMapName" .) }}
- name: postgres-ca
  mountPath: /etc/tracecat/certs/postgres
  readOnly: true
{{- end }}
{{- end }}

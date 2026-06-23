{{/*
URLs, LiteLLM endpoint & Gateway API route rules for the Tracecat chart.
This file is loaded by Helm alongside the other templates/*.tpl files.
*/}}

{{/*
LiteLLM internal service name + base URL
*/}}
{{- define "tracecat.litellmServiceName" -}}
{{- printf "%s-litellm" (include "tracecat.fullname" .) -}}
{{- end }}

{{- define "tracecat.litellmBaseUrl" -}}
{{- if .Values.litellm.baseUrl -}}
{{- .Values.litellm.baseUrl -}}
{{- else -}}
{{- printf "http://%s:%v" (include "tracecat.litellmServiceName" .) .Values.litellm.port -}}
{{- end -}}
{{- end }}

{{/*
Bundled Redis service name (CloudPirates subchart). Release-name safe: the
subchart names its Service "<release>-redis". An explicit
bridgeSecrets.redisServiceName overrides (e.g. external/shared redis).
*/}}
{{- define "tracecat.redisServiceName" -}}
{{- if .Values.bridgeSecrets.redisServiceName -}}
{{- .Values.bridgeSecrets.redisServiceName -}}
{{- else if .Values.redis.fullnameOverride -}}
{{- .Values.redis.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default "redis" .Values.redis.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end }}

{{/*
Bundled RustFS service name. Release-name safe: the subchart names its Service
"<rustfs-fullname>-svc" where rustfs-fullname is "<release>-rustfs".
*/}}
{{- define "tracecat.rustfsServiceName" -}}
{{- if .Values.rustfs.fullnameOverride -}}
{{- printf "%s-svc" (.Values.rustfs.fullnameOverride | trunc 59 | trimSuffix "-") -}}
{{- else -}}
{{- $name := default "rustfs" .Values.rustfs.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- printf "%s-svc" (.Release.Name | trunc 59 | trimSuffix "-") -}}
{{- else -}}
{{- printf "%s-%s-svc" .Release.Name $name -}}
{{- end -}}
{{- end -}}
{{- end }}

{{- define "tracecat.rustfsEndpoint" -}}
{{- printf "http://%s:9000" (include "tracecat.rustfsServiceName" .) -}}
{{- end }}

{{/*
Gateway API HTTPRoute rules (shared by combined + split routes).
*/}}
{{- define "tracecat.gatewayApiRule" -}}
- matches:
    - path:
        type: PathPrefix
        value: /api
  backendRefs:
    - name: {{ include "tracecat.fullname" . }}-api
      port: 8000
{{- end }}

{{- define "tracecat.gatewayUiRule" -}}
- matches:
    - path:
        type: PathPrefix
        value: /
  backendRefs:
    - name: {{ include "tracecat.fullname" . }}-ui
      port: 3000
{{- end }}

{{- define "tracecat.gatewayMcpRule" -}}
- matches:
    - path:
        type: PathPrefix
        value: /mcp
    - path:
        type: Exact
        value: /.well-known/oauth-authorization-server
    - path:
        type: PathPrefix
        value: /.well-known/oauth-protected-resource
    - path:
        type: PathPrefix
        value: /authorize
    - path:
        type: Exact
        value: /token
    - path:
        type: Exact
        value: /register
    - path:
        type: PathPrefix
        value: /consent
    - path:
        type: PathPrefix
        value: /auth/callback
  backendRefs:
    - name: {{ include "tracecat.fullname" . }}-mcp
      port: {{ .Values.mcp.port }}
{{- end }}

{{/*
URL scheme - returns https if TLS is configured, http otherwise
*/}}
{{- define "tracecat.urlScheme" -}}
{{- if .Values.ingress.tls }}https{{- else }}http{{- end }}
{{- end }}

{{/*
Public App URL - used for browser redirects and public-facing links
*/}}
{{- define "tracecat.publicAppUrl" -}}
{{- if .Values.urls.publicApp }}
{{- .Values.urls.publicApp }}
{{- else }}
{{- printf "%s://%s" (include "tracecat.urlScheme" .) .Values.ingress.host }}
{{- end }}
{{- end }}

{{/*
Public API URL - used for external API access
*/}}
{{- define "tracecat.publicApiUrl" -}}
{{- if .Values.urls.publicApi }}
{{- .Values.urls.publicApi }}
{{- else }}
{{- printf "%s://%s/api" (include "tracecat.urlScheme" .) .Values.ingress.host }}
{{- end }}
{{- end }}

{{/*
Public MCP URL - base URL for MCP OAuth metadata and auth routes.
Must NOT include the /mcp path: FastMCP mounts auth routes (register,
token, authorize) at the server root, so the base_url that drives the
OAuth discovery document must point there.
*/}}
{{- define "tracecat.publicMcpUrl" -}}
{{- if .Values.urls.publicMcp }}
{{- .Values.urls.publicMcp }}
{{- else }}
{{- printf "%s://%s" (include "tracecat.urlScheme" .) .Values.ingress.host }}
{{- end }}
{{- end }}

{{/*
Public S3 URL - used for presigned URLs
*/}}
{{- define "tracecat.publicS3Url" -}}
{{- if .Values.urls.publicS3 }}
{{- .Values.urls.publicS3 }}
{{- else }}
{{- "" }}
{{- end }}
{{- end }}

{{/*
Internal API URL - used for service-to-service communication
*/}}
{{- define "tracecat.internalApiUrl" -}}
{{- printf "http://%s-api:8000" (include "tracecat.fullname" .) }}
{{- end }}

{{/*
Internal Blob Storage URL
*/}}
{{- define "tracecat.blobStorageEndpoint" -}}
{{- if .Values.tracecat.blobStorage.endpoint -}}
{{- .Values.tracecat.blobStorage.endpoint -}}
{{- else if .Values.externalS3.endpoint -}}
{{- .Values.externalS3.endpoint -}}
{{- else if .Values.rustfs.enabled -}}
{{- include "tracecat.rustfsEndpoint" . -}}
{{- end -}}
{{- end }}

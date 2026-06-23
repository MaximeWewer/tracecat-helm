{{/*
ServiceAccount name resolution for the Tracecat chart.
This file is loaded by Helm alongside the other templates/*.tpl files.
*/}}

{{/*
Service account name for Tracecat workloads
*/}}
{{- define "tracecat.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- if .Values.serviceAccount.name -}}
{{- .Values.serviceAccount.name -}}
{{- else -}}
{{- printf "%s-app" (include "tracecat.fullname" .) -}}
{{- end -}}
{{- else -}}
{{- .Values.serviceAccount.name | default "default" -}}
{{- end -}}
{{- end }}

{{/*
Executor service account name
*/}}
{{- define "tracecat.executorServiceAccountName" -}}
{{- if .Values.executor.serviceAccount.create -}}
{{- if .Values.executor.serviceAccount.name -}}
{{- .Values.executor.serviceAccount.name -}}
{{- else -}}
{{- printf "%s-executor" (include "tracecat.fullname" .) -}}
{{- end -}}
{{- else -}}
{{- .Values.executor.serviceAccount.name | default (include "tracecat.serviceAccountName" .) -}}
{{- end -}}
{{- end }}

{{/*
Agent worker service account name
*/}}
{{- define "tracecat.agentWorkerServiceAccountName" -}}
{{- if .Values.agentWorker.serviceAccount.create -}}
{{- if .Values.agentWorker.serviceAccount.name -}}
{{- .Values.agentWorker.serviceAccount.name -}}
{{- else -}}
{{- printf "%s-agent-worker" (include "tracecat.fullname" .) -}}
{{- end -}}
{{- else -}}
{{- .Values.agentWorker.serviceAccount.name | default (include "tracecat.serviceAccountName" .) -}}
{{- end -}}
{{- end }}

{{/*
Agent executor service account name
*/}}
{{- define "tracecat.agentExecutorServiceAccountName" -}}
{{- if .Values.agentExecutor.serviceAccount.create -}}
{{- if .Values.agentExecutor.serviceAccount.name -}}
{{- .Values.agentExecutor.serviceAccount.name -}}
{{- else -}}
{{- printf "%s-agent-executor" (include "tracecat.fullname" .) -}}
{{- end -}}
{{- else -}}
{{- .Values.agentExecutor.serviceAccount.name | default (include "tracecat.executorServiceAccountName" .) -}}
{{- end -}}
{{- end }}

{{/*
LiteLLM service account name
*/}}
{{- define "tracecat.litellmServiceAccountName" -}}
{{- if .Values.litellm.serviceAccount.create -}}
{{- if .Values.litellm.serviceAccount.name -}}
{{- .Values.litellm.serviceAccount.name -}}
{{- else -}}
{{- printf "%s-litellm" (include "tracecat.fullname" .) -}}
{{- end -}}
{{- else -}}
{{- .Values.litellm.serviceAccount.name | default (include "tracecat.serviceAccountName" .) -}}
{{- end -}}
{{- end }}

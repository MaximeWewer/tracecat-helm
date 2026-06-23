{{/*
Naming, labels & image tags for the Tracecat chart.
This file is loaded by Helm alongside the other templates/*.tpl files.
*/}}

{{/*
Chart name
*/}}
{{- define "tracecat.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Fully qualified app name (truncated to 63 chars for K8s naming)
*/}}
{{- define "tracecat.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version for chart label
*/}}
{{- define "tracecat.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Shared backend image tag used by backend workloads and version labels
*/}}
{{- define "tracecat.imageTag" -}}
{{- .Values.image.tag | default .Chart.AppVersion -}}
{{- end }}

{{/*
UI image tag used by frontend workload
*/}}
{{- define "tracecat.uiImageTag" -}}
{{- .Values.uiImage.tag | default .Chart.AppVersion -}}
{{- end }}

{{/*
Full image references (digest takes precedence over tag for supply-chain pinning)
*/}}
{{- define "tracecat.backendImage" -}}
{{- if .Values.image.digest -}}
{{- printf "%s@%s" .Values.image.repository .Values.image.digest -}}
{{- else -}}
{{- printf "%s:%s" .Values.image.repository (include "tracecat.imageTag" .) -}}
{{- end -}}
{{- end }}

{{- define "tracecat.uiImageRef" -}}
{{- if .Values.uiImage.digest -}}
{{- printf "%s@%s" .Values.uiImage.repository .Values.uiImage.digest -}}
{{- else -}}
{{- printf "%s:%s" .Values.uiImage.repository (include "tracecat.uiImageTag" .) -}}
{{- end -}}
{{- end }}

{{- define "tracecat.initImageRef" -}}
{{- if .Values.initImage.digest -}}
{{- printf "%s@%s" .Values.initImage.repository .Values.initImage.digest -}}
{{- else -}}
{{- printf "%s:%s" .Values.initImage.repository .Values.initImage.tag -}}
{{- end -}}
{{- end }}

{{/*
Common labels
*/}}
{{- define "tracecat.labels" -}}
helm.sh/chart: {{ include "tracecat.chart" . }}
{{ include "tracecat.selectorLabels" . }}
{{- $version := include "tracecat.imageTag" . | trim }}
{{- if $version }}
app.kubernetes.io/version: {{ $version | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "tracecat.selectorLabels" -}}
app.kubernetes.io/name: {{ include "tracecat.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

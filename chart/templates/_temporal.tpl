{{/*
Temporal naming, cluster URL, namespace & queue helpers for the Tracecat chart.
This file is loaded by Helm alongside the other templates/*.tpl files.
*/}}

{{/*
Temporal admin-tools image for the chart's init/setup containers.
*/}}
{{- define "tracecat.temporalAdminToolsImage" -}}
{{- .Values.tracecat.temporal.adminToolsImage -}}
{{- end }}

{{/*
Temporal Fullname - mirrors the subchart naming logic
*/}}
{{- define "tracecat.temporalFullname" -}}
{{- if .Values.temporal.fullnameOverride }}
{{- .Values.temporal.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default "temporal" .Values.temporal.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Temporal Cluster URL - supports both subchart and external Temporal
*/}}
{{- define "tracecat.temporalClusterUrl" -}}
{{- if .Values.temporal.enabled }}
{{- $values := .Values | toYaml | fromYaml -}}
{{- $port := dig "temporal" "server" "frontend" "service" "port" 7233 $values -}}
{{- printf "%s-frontend:%v" (include "tracecat.temporalFullname" .) $port }}
{{- else if .Values.externalTemporal.enabled }}
{{- required "externalTemporal.clusterUrl is required when using external Temporal" .Values.externalTemporal.clusterUrl }}
{{- else }}
{{- fail "Either temporal.enabled or externalTemporal.enabled must be true" }}
{{- end }}
{{- end }}

{{/*
Temporal Namespace
*/}}
{{- define "tracecat.temporalNamespace" -}}
{{- if .Values.temporal.enabled }}
{{- $values := .Values | toYaml | fromYaml -}}
{{- $namespaces := dig "temporal" "server" "config" "namespaces" "namespace" list $values -}}
{{- if and $namespaces (gt (len $namespaces) 0) -}}
{{- $namespace := index $namespaces 0 -}}
{{- index $namespace "name" | default "default" -}}
{{- else -}}
{{- "default" -}}
{{- end }}
{{- else if .Values.externalTemporal.enabled }}
{{- .Values.externalTemporal.clusterNamespace | default "default" }}
{{- else }}
{{- "default" }}
{{- end }}
{{- end }}

{{/*
Temporal Namespace Retention
*/}}
{{- define "tracecat.temporalNamespaceRetention" -}}
{{- if .Values.temporal.enabled }}
{{- $values := .Values | toYaml | fromYaml -}}
{{- $namespaces := dig "temporal" "server" "config" "namespaces" "namespace" list $values -}}
{{- if and $namespaces (gt (len $namespaces) 0) -}}
{{- $namespace := index $namespaces 0 -}}
{{- index $namespace "retention" | default "720h" -}}
{{- else -}}
{{- "720h" -}}
{{- end }}
{{- else }}
{{- "720h" -}}
{{- end }}
{{- end }}

{{/*
Temporal Namespace History Archival State
*/}}
{{- define "tracecat.temporalNamespaceHistoryArchivalState" -}}
{{- if .Values.temporal.enabled }}
{{- $values := .Values | toYaml | fromYaml -}}
{{- dig "temporal" "server" "namespaceDefaults" "archival" "history" "state" "" $values -}}
{{- else -}}
{{- "" -}}
{{- end }}
{{- end }}

{{/*
Temporal Namespace History Archival URI
*/}}
{{- define "tracecat.temporalNamespaceHistoryArchivalURI" -}}
{{- if .Values.temporal.enabled }}
{{- $values := .Values | toYaml | fromYaml -}}
{{- dig "temporal" "server" "namespaceDefaults" "archival" "history" "URI" "" $values -}}
{{- else -}}
{{- "" -}}
{{- end }}
{{- end }}

{{/*
Temporal Namespace Visibility Archival State
*/}}
{{- define "tracecat.temporalNamespaceVisibilityArchivalState" -}}
{{- if .Values.temporal.enabled }}
{{- $values := .Values | toYaml | fromYaml -}}
{{- dig "temporal" "server" "namespaceDefaults" "archival" "visibility" "state" "" $values -}}
{{- else -}}
{{- "" -}}
{{- end }}
{{- end }}

{{/*
Temporal Namespace Visibility Archival URI
*/}}
{{- define "tracecat.temporalNamespaceVisibilityArchivalURI" -}}
{{- if .Values.temporal.enabled }}
{{- $values := .Values | toYaml | fromYaml -}}
{{- dig "temporal" "server" "namespaceDefaults" "archival" "visibility" "URI" "" $values -}}
{{- else -}}
{{- "" -}}
{{- end }}
{{- end }}

{{/*
Temporal Queue
*/}}
{{- define "tracecat.temporalQueue" -}}
{{- if .Values.externalTemporal.enabled }}
{{- .Values.externalTemporal.clusterQueue | default "tracecat-task-queue" -}}
{{- else if .Values.temporal.enabled }}
{{- .Values.temporal.clusterQueue | default "tracecat-task-queue" -}}
{{- else }}
{{- "tracecat-task-queue" -}}
{{- end }}
{{- end }}

{{/*
Prometheus metrics helpers.

Tracecat itself serves no /metrics HTTP route: the only Prometheus endpoint its
processes expose is the Temporal SDK exporter, armed per-process by
TEMPORAL__METRICS_PORT. Any process opening a Temporal client then serves
GET <port>/metrics. So "component" here means a Tracecat workload, and the
values key (metrics.tracecat.components.<key>) is camelCase while the
app.kubernetes.io/component label is kebab-case.
*/}}

{{/*
Map of metrics.tracecat.components key -> app.kubernetes.io/component label.
*/}}
{{- define "tracecat.metrics.componentMap" -}}
api: api
worker: worker
executor: executor
agentWorker: agent-worker
agentExecutor: agent-executor
mcp: mcp
{{- end -}}

{{/*
Whether the Temporal SDK exporter is enabled for one Tracecat component.
Emits a non-empty string when true (use with `if`).
  include "tracecat.metrics.enabledFor" (dict "root" $ "component" "worker")
*/}}
{{- define "tracecat.metrics.enabledFor" -}}
{{- $m := .root.Values.metrics.tracecat -}}
{{- if and $m.enabled (dig .component false $m.components) -}}
{{- if and (eq .component "mcp") (not .root.Values.mcp.enabled) -}}
{{- else -}}
enabled
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Keys of the Tracecat components whose exporter is enabled, as a JSON list of the
app.kubernetes.io/component *labels* (kebab-case). Empty list when none.
*/}}
{{- define "tracecat.metrics.enabledComponentLabels" -}}
{{- $root := . -}}
{{- $map := fromYaml (include "tracecat.metrics.componentMap" .) -}}
{{- $out := list -}}
{{- range $key, $label := $map -}}
{{- if include "tracecat.metrics.enabledFor" (dict "root" $root "component" $key) -}}
{{- $out = append $out $label -}}
{{- end -}}
{{- end -}}
{{- $out | sortAlpha | toJson -}}
{{- end -}}

{{/*
prometheus.io/* scrape annotations for a Tracecat pod/Service, or nothing.
  include "tracecat.metrics.scrapeAnnotations" (dict "root" $ "component" "worker")
*/}}
{{- define "tracecat.metrics.scrapeAnnotations" -}}
{{- $m := .root.Values.metrics.tracecat -}}
{{- if and (include "tracecat.metrics.enabledFor" .) $m.scrape -}}
prometheus.io/scrape: "true"
prometheus.io/port: {{ $m.port | quote }}
prometheus.io/path: {{ $m.path | default "/metrics" | quote }}
{{- end -}}
{{- end -}}

{{/*
The `metrics` container port entry for a Tracecat workload, or nothing.
  include "tracecat.metrics.containerPort" (dict "root" $ "component" "worker")
*/}}
{{- define "tracecat.metrics.containerPort" -}}
{{- if include "tracecat.metrics.enabledFor" . -}}
- name: metrics
  containerPort: {{ .root.Values.metrics.tracecat.port }}
  protocol: TCP
{{- end -}}
{{- end -}}

{{/*
Does a Tracecat workload need a pod `annotations:` key at all? (reloader,
metrics scrape, or user-supplied podAnnotations).
  include "tracecat.metrics.needsPodAnnotations" (dict "root" $ "component" "worker")
*/}}
{{- define "tracecat.metrics.needsPodAnnotations" -}}
{{- $root := .root -}}
{{- if or $root.Values.reloader.enabled $root.Values.podAnnotations (and (include "tracecat.metrics.enabledFor" .) $root.Values.metrics.tracecat.scrape) -}}
yes
{{- end -}}
{{- end -}}

{{/*
TEMPORAL__METRICS_PORT for one Tracecat component, or nothing. This is what arms
the Temporal SDK Prometheus exporter inside the process.
  include "tracecat.metrics.env" (dict "root" $ "component" "worker")
*/}}
{{- define "tracecat.metrics.env" -}}
{{- if include "tracecat.metrics.enabledFor" . }}
- name: TEMPORAL__METRICS_PORT
  value: {{ .root.Values.metrics.tracecat.port | quote }}
{{- end }}
{{- end -}}

{{/*
ServiceMonitor labels: chart labels + shared additionalLabels + per-block
additionalLabels (per-block wins). Rendered without a leading newline; call with
`nindent 4`.
  include "tracecat.metrics.smLabels" (dict "root" $ "block" $.Values.metrics.tracecat.serviceMonitor)
*/}}
{{- define "tracecat.metrics.smLabels" -}}
{{- $shared := .root.Values.metrics.serviceMonitor.additionalLabels | default dict -}}
{{- $own := (.block).additionalLabels | default dict -}}
{{ include "tracecat.labels" .root }}
{{- with (merge (deepCopy $own) $shared) }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{/*
ServiceMonitor endpoint scrape settings (interval/scrapeTimeout), inheriting the
shared metrics.serviceMonitor defaults. Call with `nindent 6`.
  include "tracecat.metrics.smScrape" (dict "root" $ "block" <serviceMonitor block>)
*/}}
{{- define "tracecat.metrics.smScrape" -}}
{{- $shared := .root.Values.metrics.serviceMonitor -}}
{{- $own := .block | default dict -}}
interval: {{ ($own.interval | default $shared.interval | default "30s") | quote }}
{{- $timeout := $own.scrapeTimeout | default $shared.scrapeTimeout }}
{{- if $timeout }}
scrapeTimeout: {{ $timeout | quote }}
{{- end }}
{{- end -}}

{{/*
Name of the bundled CloudPirates redis metrics Service (<redis fullname>-metrics).
Mirrors the subchart's cloudpirates.fullname; deliberately ignores
bridgeSecrets.redisServiceName (that points at an external redis, which this
chart does not scrape).
*/}}
{{- define "tracecat.metrics.redisServiceName" -}}
{{- if .Values.redis.fullnameOverride -}}
{{- printf "%s-metrics" (.Values.redis.fullnameOverride | trunc 55 | trimSuffix "-") -}}
{{- else -}}
{{- $name := default "redis" .Values.redis.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- printf "%s-metrics" (.Release.Name | trunc 55 | trimSuffix "-") -}}
{{- else -}}
{{- printf "%s-%s-metrics" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
app.kubernetes.io/name of the bundled Temporal subchart (mirrors temporal.name).
*/}}
{{- define "tracecat.metrics.temporalName" -}}
{{- default "temporal" .Values.temporal.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

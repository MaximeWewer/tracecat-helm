{{/*
Workload shaping: scheduling, securityContext, init, extra env for the Tracecat chart.
This file is loaded by Helm alongside the other templates/*.tpl files.
*/}}

{{/*
Global extra env (appended to every container's env list). Escape hatch.
*/}}
{{- define "tracecat.extraEnv" -}}
{{- with .Values.extraEnv }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Global extra envFrom — renders the whole `envFrom:` key when set.
Place at container level (sibling of env:).
*/}}
{{- define "tracecat.extraEnvFrom" -}}
{{- with .Values.extraEnvFrom }}
envFrom:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Hardened container securityContext (drop ALL caps, no privilege escalation).
*/}}
{{- define "tracecat.containerSecurityContext" -}}
{{- with .Values.containerSecurityContext }}
securityContext:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Same hardening but with a writable root filesystem — for the executor and
agent-executor, which run arbitrary integration/action code that may write
outside /tmp.
*/}}
{{- define "tracecat.containerSecurityContextExec" -}}
{{- $sc := omit .Values.containerSecurityContext "readOnlyRootFilesystem" -}}
securityContext:
  readOnlyRootFilesystem: false
  {{- with $sc }}
  {{- toYaml . | nindent 2 }}
  {{- end }}
{{- end }}

{{/*
Liveness probe for the Temporal workers (no HTTP server) — uses the SDK metrics
port when metrics are enabled, so a hung worker gets restarted. Place at the
container level.
*/}}
{{- define "tracecat.workerLivenessProbe" -}}
{{- if .Values.tracecat.temporal.metrics.enabled }}
livenessProbe:
  tcpSocket:
    port: metrics
  initialDelaySeconds: 30
  periodSeconds: 20
  failureThreshold: 3
{{- end }}
{{- end }}

{{/*
Shared initContainer that blocks until the app PostgreSQL is reachable.
Use inside an `initContainers:` list.
*/}}
{{- define "tracecat.initWaitPostgres" -}}
- name: wait-for-postgres
  image: "{{ include "tracecat.initImageRef" . }}"
  imagePullPolicy: {{ .Values.initImage.pullPolicy }}
  command: ['sh', '-c']
  resources:
    requests:
      cpu: 10m
      memory: 16Mi
    limits:
      memory: 32Mi
  args:
    - |
      HOST="{{ include "tracecat.postgres.host" . }}"
      PORT="{{ include "tracecat.postgres.port" . }}"
      echo "Waiting for PostgreSQL at $HOST:$PORT ..."
      until nc -z -w3 "$HOST" "$PORT"; do
        echo "PostgreSQL not ready, waiting 5s..."
        sleep 5
      done
      echo "PostgreSQL is ready"
  securityContext:
    allowPrivilegeEscalation: false
    runAsNonRoot: true
    runAsUser: 1001
    readOnlyRootFilesystem: true
    capabilities:
      drop:
        - ALL
    seccompProfile:
      type: RuntimeDefault
{{- end }}

{{/*
Pod scheduling helpers (nodeSelector, affinity, tolerations, topology spread)
*/}}
{{- define "tracecat.topologySpreadConstraints" -}}
{{- $root := .root -}}
{{- $component := .component -}}
{{- $constraints := .constraints -}}
{{- if $constraints }}
topologySpreadConstraints:
{{- range $c := $constraints }}
  - maxSkew: {{ $c.maxSkew | default 1 }}
    topologyKey: {{ $c.topologyKey | quote }}
    whenUnsatisfiable: {{ $c.whenUnsatisfiable | default "ScheduleAnyway" }}
    {{- if $c.minDomains }}
    minDomains: {{ $c.minDomains }}
    {{- end }}
    labelSelector:
      matchLabels:
        {{- include "tracecat.selectorLabels" $root | nindent 8 }}
        app.kubernetes.io/component: {{ $component }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Pod-spec preamble shared by every workload: imagePullSecrets,
automountServiceAccountToken, nodeSelector/affinity/tolerations/topologySpread,
and a default soft pod anti-affinity (spread replicas across nodes).
*/}}
{{- define "tracecat.podScheduling" -}}
{{- $root := .root -}}
{{- $component := .component -}}
{{- $scheduling := $root.Values.scheduling -}}
{{- with $root.Values.imagePullSecrets }}
imagePullSecrets:
{{ toYaml . | nindent 2 }}
{{- end }}
automountServiceAccountToken: {{ $root.Values.serviceAccount.automountServiceAccountToken }}
{{- if $scheduling }}
{{- $nodeSelector := dict -}}
{{- with $scheduling.nodeSelector }}
{{- range $key, $value := . }}
{{- $_ := set $nodeSelector $key $value -}}
{{- end }}
{{- end }}
{{- if and $scheduling.architecture (not (hasKey $nodeSelector "kubernetes.io/arch")) }}
{{- $_ := set $nodeSelector "kubernetes.io/arch" $scheduling.architecture -}}
{{- end }}
{{- if $nodeSelector }}
nodeSelector:
{{ toYaml $nodeSelector | nindent 2 }}
{{- end }}
{{- if $scheduling.affinity }}
affinity:
{{ toYaml $scheduling.affinity | nindent 2 }}
{{- else if $scheduling.podAntiAffinity.enabled }}
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          topologyKey: {{ $scheduling.podAntiAffinity.topologyKey | default "kubernetes.io/hostname" }}
          labelSelector:
            matchLabels:
              {{- include "tracecat.selectorLabels" $root | nindent 14 }}
              app.kubernetes.io/component: {{ $component }}
{{- end }}
{{- with $scheduling.tolerations }}
tolerations:
{{ toYaml . | nindent 2 }}
{{- end }}
{{- if $scheduling.topologySpreadConstraints }}
{{ include "tracecat.topologySpreadConstraints" (dict "root" $root "component" $component "constraints" $scheduling.topologySpreadConstraints) }}
{{- end }}
{{- end }}
{{- end }}

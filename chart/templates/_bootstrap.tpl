{{/*
Bootstrap helpers (templates/bootstrap-*.yaml).

Each declared secret key gets an env var TC_BOOTSTRAP_S<i>_K<j>: either a
literal `value` (rendered into the Job spec, so non-sensitive data only) or a
`secretKeyRef` to a Kubernetes Secret. The spec handed to the script only
carries the env var names, never the values.
*/}}
{{- define "tracecat.bootstrap.secretsSpec" -}}
{{- $specs := list }}
{{- range $i, $s := .Values.bootstrap.secrets }}
{{- $keys := list }}
{{- range $j, $k := $s.keys }}
{{- $keys = append $keys (dict "key" $k.key "env" (printf "TC_BOOTSTRAP_S%d_K%d" $i $j)) }}
{{- end }}
{{- $spec := dict "name" $s.name "keys" $keys "environment" ($s.environment | default "default") "type" ($s.type | default "custom") }}
{{- with $s.description }}{{ $_ := set $spec "description" . }}{{ end }}
{{- $specs = append $specs $spec }}
{{- end }}
{{- toJson $specs }}
{{- end -}}

{{- define "tracecat.bootstrap.secretsEnv" -}}
{{- range $i, $s := .Values.bootstrap.secrets }}
{{- range $j, $k := $s.keys }}
{{- if eq (hasKey $k "value") (hasKey $k "secretKeyRef") }}
{{- fail (printf "bootstrap.secrets[%d] (%s) key %q: set exactly one of value, secretKeyRef" $i $s.name $k.key) }}
{{- end }}
- name: {{ printf "TC_BOOTSTRAP_S%d_K%d" $i $j }}
  {{- if hasKey $k "secretKeyRef" }}
  valueFrom:
    secretKeyRef:
      name: {{ required (printf "bootstrap.secrets[%d].keys[%d].secretKeyRef.name" $i $j) $k.secretKeyRef.name }}
      key: {{ required (printf "bootstrap.secrets[%d].keys[%d].secretKeyRef.key" $i $j) $k.secretKeyRef.key }}
      {{- if hasKey $k.secretKeyRef "optional" }}
      optional: {{ $k.secretKeyRef.optional }}
      {{- end }}
  {{- else }}
  value: {{ $k.value | toString | quote }}
  {{- end }}
{{- end }}
{{- end }}
{{- end -}}

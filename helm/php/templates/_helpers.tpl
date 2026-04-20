{{/*
Standard application labels
*/}}
{{- define "php.labels.standard" -}}
app.kubernetes.io/name: {{ .Chart.Name | quote }}
app.kubernetes.io/component: {{ .Chart.Name | quote }}
app.kubernetes.io/instance: {{ .Release.Name | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service | quote }}
helm.sh/chart: "{{ .Chart.Name }}-{{ .Chart.Version }}"
{{- end -}}
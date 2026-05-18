{{/*
Common labels
*/}}
{{- define "hello.labels" -}}
app.kubernetes.io/name: hello
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Service account name
*/}}
{{- define "hello.serviceAccountName" -}}
{{ .Release.Name }}-hello-sa
{{- end }}

{{/*
Full name
*/}}
{{- define "hello.fullname" -}}
{{ .Release.Name }}-hello
{{- end }}

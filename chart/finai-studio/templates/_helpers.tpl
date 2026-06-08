{{/*
Common helpers for the FinAI Studio chart.
*/}}

{{- define "finai.name" -}}
{{- default "finai-studio" .Values.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "finai.labels" -}}
app.kubernetes.io/name: {{ include "finai.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: finai-studio
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end -}}

{{/* Vertex AI project falls back to the customer project when unset. */}}
{{- define "finai.vertexProject" -}}
{{- if .Values.vertexAi.projectName -}}
{{ .Values.vertexAi.projectName }}
{{- else -}}
{{ .Values.customer.projectId }}
{{- end -}}
{{- end -}}

{{/* SQLAlchemy URI assembled from database.* (Cloud SQL Proxy on localhost). */}}
{{- define "finai.sqlalchemyUri" -}}
postgresql+asyncpg://{{ .Values.database.user }}:$(DB_PASSWORD)@{{ .Values.database.host | default "127.0.0.1" }}:{{ .Values.database.port }}/{{ .Values.database.name }}
{{- end -}}

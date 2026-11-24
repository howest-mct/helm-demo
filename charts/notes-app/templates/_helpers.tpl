{{/*
Chart name, truncated to 63 characters (the DNS label limit).
*/}}
{{- define "notes-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Full name used as prefix for every resource: <release>-<chart>,
or just <release> when the release name already contains the chart name.
*/}}
{{- define "notes-app.fullname" -}}
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
Name of one component, e.g. include "notes-app.componentName" (list . "api")
*/}}
{{- define "notes-app.componentName" -}}
{{- $ctx := index . 0 }}
{{- printf "%s-%s" (include "notes-app.fullname" $ctx | trunc 56 | trimSuffix "-") (index . 1) }}
{{- end }}

{{- define "notes-app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Labels on every resource.
*/}}
{{- define "notes-app.labels" -}}
helm.sh/chart: {{ include "notes-app.chart" . }}
{{ include "notes-app.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Labels a Service uses to find its pods. Add the component label next to it.
*/}}
{{- define "notes-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "notes-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "notes-app.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "notes-app.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "notes-app.apiImage" -}}
{{- printf "%s:%s" .Values.api.image.repository (default .Chart.AppVersion .Values.api.image.tag) }}
{{- end }}

{{/*
Database connection settings: the bundled PostgreSQL or an external one.
*/}}
{{- define "notes-app.dbHost" -}}
{{- if .Values.postgresql.enabled }}
{{- include "notes-app.componentName" (list . "postgresql") }}
{{- else }}
{{- required "externalDatabase.host is required when postgresql.enabled is false" .Values.externalDatabase.host }}
{{- end }}
{{- end }}

{{- define "notes-app.dbPort" -}}
{{- if .Values.postgresql.enabled }}5432{{ else }}{{ .Values.externalDatabase.port }}{{ end }}
{{- end }}

{{- define "notes-app.dbName" -}}
{{- if .Values.postgresql.enabled }}{{ .Values.postgresql.auth.database }}{{ else }}{{ .Values.externalDatabase.database }}{{ end }}
{{- end }}

{{- define "notes-app.dbUser" -}}
{{- if .Values.postgresql.enabled }}{{ .Values.postgresql.auth.username }}{{ else }}{{ .Values.externalDatabase.username }}{{ end }}
{{- end }}

{{/*
Name of the Secret that holds the database password (key: password).
*/}}
{{- define "notes-app.dbSecretName" -}}
{{- if and .Values.postgresql.enabled .Values.postgresql.auth.existingSecret }}
{{- .Values.postgresql.auth.existingSecret }}
{{- else if and (not .Values.postgresql.enabled) .Values.externalDatabase.existingSecret }}
{{- .Values.externalDatabase.existingSecret }}
{{- else }}
{{- include "notes-app.componentName" (list . "db") }}
{{- end }}
{{- end }}

{{- define "notes-app.createDbSecret" -}}
{{- if .Values.postgresql.enabled }}
{{- if not .Values.postgresql.auth.existingSecret }}true{{ end }}
{{- else }}
{{- if not .Values.externalDatabase.existingSecret }}true{{ end }}
{{- end }}
{{- end }}

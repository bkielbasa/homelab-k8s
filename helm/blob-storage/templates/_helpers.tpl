{{/*
Expand the name of the chart.
*/}}
{{- define "blob-storage.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "blob-storage.fullname" -}}
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
Create chart name and version as used by the chart label.
*/}}
{{- define "blob-storage.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "blob-storage.labels" -}}
helm.sh/chart: {{ include "blob-storage.chart" . }}
{{ include "blob-storage.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "blob-storage.selectorLabels" -}}
app.kubernetes.io/name: {{ include "blob-storage.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Master labels
*/}}
{{- define "blob-storage.master.labels" -}}
{{ include "blob-storage.labels" . }}
app.kubernetes.io/component: master
{{- end }}

{{/*
Master selector labels
*/}}
{{- define "blob-storage.master.selectorLabels" -}}
{{ include "blob-storage.selectorLabels" . }}
app.kubernetes.io/component: master
{{- end }}

{{/*
Chunkserver labels
*/}}
{{- define "blob-storage.chunkserver.labels" -}}
{{ include "blob-storage.labels" . }}
app.kubernetes.io/component: chunkserver
{{- end }}

{{/*
Chunkserver selector labels
*/}}
{{- define "blob-storage.chunkserver.selectorLabels" -}}
{{ include "blob-storage.selectorLabels" . }}
app.kubernetes.io/component: chunkserver
{{- end }}

{{/*
Client labels
*/}}
{{- define "blob-storage.client.labels" -}}
{{ include "blob-storage.labels" . }}
app.kubernetes.io/component: client
{{- end }}

{{/*
Client selector labels
*/}}
{{- define "blob-storage.client.selectorLabels" -}}
{{ include "blob-storage.selectorLabels" . }}
app.kubernetes.io/component: client
{{- end }}

{{/*
Frontend labels
*/}}
{{- define "blob-storage.frontend.labels" -}}
{{ include "blob-storage.labels" . }}
app.kubernetes.io/component: frontend
{{- end }}

{{/*
Frontend selector labels
*/}}
{{- define "blob-storage.frontend.selectorLabels" -}}
{{ include "blob-storage.selectorLabels" . }}
app.kubernetes.io/component: frontend
{{- end }}

{{/*
Master image
*/}}
{{- define "blob-storage.master.image" -}}
{{- $registry := .Values.master.image.registry | default .Values.global.imageRegistry -}}
{{- $repository := .Values.master.image.repository -}}
{{- $tag := .Values.master.image.tag | default .Values.global.imageTag | default .Chart.AppVersion -}}
{{- if $registry }}
{{- printf "%s/%s:%s" $registry $repository $tag }}
{{- else }}
{{- printf "%s:%s" $repository $tag }}
{{- end }}
{{- end }}

{{/*
Chunkserver image
*/}}
{{- define "blob-storage.chunkserver.image" -}}
{{- $registry := .Values.chunkserver.image.registry | default .Values.global.imageRegistry -}}
{{- $repository := .Values.chunkserver.image.repository -}}
{{- $tag := .Values.chunkserver.image.tag | default .Values.global.imageTag |default .Chart.AppVersion -}}
{{- if $registry }}
{{- printf "%s/%s:%s" $registry $repository $tag }}
{{- else }}
{{- printf "%s:%s" $repository $tag }}
{{- end }}
{{- end }}

{{/*
Client image
*/}}
{{- define "blob-storage.client.image" -}}
{{- $registry := .Values.client.image.registry | default .Values.global.imageRegistry -}}
{{- $repository := .Values.client.image.repository -}}
{{- $tag := .Values.client.image.tag | default .Values.global.imageTag |default .Chart.AppVersion -}}
{{- if $registry }}
{{- printf "%s/%s:%s" $registry $repository $tag }}
{{- else }}
{{- printf "%s:%s" $repository $tag }}
{{- end }}
{{- end }}

{{/*
Frontend image
*/}}
{{- define "blob-storage.frontend.image" -}}
{{- $registry := .Values.frontend.image.registry | default .Values.global.imageRegistry -}}
{{- $repository := .Values.frontend.image.repository -}}
{{- $tag := .Values.frontend.image.tag | default .Values.global.imageTag | default .Chart.AppVersion -}}
{{- if $registry }}
{{- printf "%s/%s:%s" $registry $repository $tag }}
{{- else }}
{{- printf "%s:%s" $repository $tag }}
{{- end }}
{{- end }}

{{/*
Master service name
*/}}
{{- define "blob-storage.master.serviceName" -}}
{{- printf "%s-master" (include "blob-storage.fullname" .) }}
{{- end }}

{{/*
Client service name
*/}}
{{- define "blob-storage.client.serviceName" -}}
{{- printf "%s-client" (include "blob-storage.fullname" .) }}
{{- end }}

{{/*
Chunkserver service name
*/}}
{{- define "blob-storage.chunkserver.serviceName" -}}
{{- printf "%s-chunkserver" (include "blob-storage.fullname" .) }}
{{- end }}

{{/*
Frontend service name
*/}}
{{- define "blob-storage.frontend.serviceName" -}}
{{- printf "%s-frontend" (include "blob-storage.fullname" .) }}
{{- end }}

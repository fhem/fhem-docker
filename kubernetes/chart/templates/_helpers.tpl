{{/*
Expand the name of the chart.
*/}}
{{- define "fhem.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "fhem.fullname" -}}
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
{{- define "fhem.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "fhem.labels" -}}
helm.sh/chart: {{ include "fhem.chart" . }}
{{ include "fhem.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "fhem.selectorLabels" -}}
app.kubernetes.io/name: {{ include "fhem.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "fhem.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "fhem.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Determine whether configDB is enabled
*/}}
{{- define "fhem.configDBEnabled" -}}
{{- if or (and .Values.configDB .Values.configDB.enabled) (and .Values.env (eq .Values.env.CONFIGTYPE "configDB")) -}}
true
{{- end -}}
{{- end }}

{{/*
Create the name of the configDB secret to use
*/}}
{{- define "fhem.configDBSecretName" -}}
{{- if and .Values.configDB .Values.configDB.existingSecret -}}
{{- .Values.configDB.existingSecret -}}
{{- else -}}
{{- printf "%s-configdb" (include "fhem.fullname" .) -}}
{{- end -}}
{{- end }}

{{/*
Return the appropriate apiVersion for PodDisruptionBudget.
*/}}
{{- define "fhem.pdb.apiVersion" -}}
{{- if .Capabilities.APIVersions.Has "policy/v1" -}}
policy/v1
{{- else -}}
policy/v1beta1
{{- end -}}
{{- end }}
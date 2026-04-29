{{- define "my-animalz.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "my-animalz.fullname" -}}
{{- printf "%s-%s" .Release.Name (include "my-animalz.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "my-animalz.labels" -}}
app.kubernetes.io/name: {{ include "my-animalz.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- end -}}

{{- define "my-animalz.selectorLabels" -}}
app.kubernetes.io/name: {{ include "my-animalz.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "my-animalz.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "my-animalz.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

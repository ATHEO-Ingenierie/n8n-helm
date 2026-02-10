{{/*
Expand the name of the chart.
*/}}
{{- define "n8n.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "n8n.fullname" -}}
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
{{- define "n8n.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "n8n.labels" -}}
helm.sh/chart: {{ include "n8n.chart" . }}
{{ include "n8n.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "n8n.selectorLabels" -}}
app.kubernetes.io/name: {{ include "n8n.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "n8n.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "n8n.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
n8n image
*/}}
{{- define "n8n.image" -}}
{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}
{{- end }}

{{/*
Returns true when queue mode is active (workers configured)
*/}}
{{- define "n8n.isQueueMode" -}}
{{- if gt (int .Values.worker.replicas) 0 -}}true{{- end -}}
{{- end }}

{{/*
Returns true if Redis is needed (queue mode or webhook enabled)
*/}}
{{- define "n8n.needsRedis" -}}
{{- if or (include "n8n.isQueueMode" .) .Values.webhook.enabled -}}true{{- end -}}
{{- end }}

{{/*
Redis host
*/}}
{{- define "n8n.redis.host" -}}
{{- if .Values.redis.enabled -}}
{{- printf "%s-redis-master" .Release.Name -}}
{{- else -}}
{{- .Values.externalRedis.host -}}
{{- end -}}
{{- end }}

{{/*
Redis port
*/}}
{{- define "n8n.redis.port" -}}
{{- if .Values.redis.enabled -}}
6379
{{- else -}}
{{- .Values.externalRedis.port | default 6379 -}}
{{- end -}}
{{- end }}

{{/*
Returns true if Redis auth is configured
*/}}
{{- define "n8n.redis.hasAuth" -}}
{{- if and .Values.redis.enabled .Values.redis.auth.enabled -}}true
{{- else if and (not .Values.redis.enabled) (or .Values.externalRedis.password .Values.externalRedis.existingSecret) -}}true
{{- end -}}
{{- end }}

{{/*
Redis password secret name
*/}}
{{- define "n8n.redis.secretName" -}}
{{- if .Values.redis.enabled -}}
{{- printf "%s-redis" .Release.Name -}}
{{- else if .Values.externalRedis.existingSecret -}}
{{- .Values.externalRedis.existingSecret -}}
{{- else -}}
{{- printf "%s-credentials" (include "n8n.fullname" .) -}}
{{- end -}}
{{- end }}

{{/*
Redis password secret key
*/}}
{{- define "n8n.redis.secretKey" -}}
{{- if .Values.redis.enabled -}}
redis-password
{{- else if .Values.externalRedis.existingSecret -}}
{{- .Values.externalRedis.existingSecretPasswordKey | default "redis-password" -}}
{{- else -}}
redis-password
{{- end -}}
{{- end }}

{{/*
Database password secret name
*/}}
{{- define "n8n.database.secretName" -}}
{{- if .Values.database.postgresdb.existingSecret -}}
{{- .Values.database.postgresdb.existingSecret -}}
{{- else -}}
{{- printf "%s-credentials" (include "n8n.fullname" .) -}}
{{- end -}}
{{- end }}

{{/*
Database password secret key
*/}}
{{- define "n8n.database.secretKey" -}}
{{- if .Values.database.postgresdb.existingSecret -}}
{{- .Values.database.postgresdb.existingSecretPasswordKey | default "password" -}}
{{- else -}}
db-password
{{- end -}}
{{- end }}

{{/*
S3 credentials secret name
*/}}
{{- define "n8n.s3.secretName" -}}
{{- if .Values.externalStorage.s3.existingSecret -}}
{{- .Values.externalStorage.s3.existingSecret -}}
{{- else -}}
{{- printf "%s-credentials" (include "n8n.fullname" .) -}}
{{- end -}}
{{- end }}

{{/*
S3 access key secret key
*/}}
{{- define "n8n.s3.accessKeySecretKey" -}}
{{- if .Values.externalStorage.s3.existingSecret -}}
{{- .Values.externalStorage.s3.existingSecretAccessKeyKey | default "access-key" -}}
{{- else -}}
s3-access-key
{{- end -}}
{{- end }}

{{/*
S3 access secret secret key
*/}}
{{- define "n8n.s3.accessSecretSecretKey" -}}
{{- if .Values.externalStorage.s3.existingSecret -}}
{{- .Values.externalStorage.s3.existingSecretAccessSecretKey | default "access-secret" -}}
{{- else -}}
s3-access-secret
{{- end -}}
{{- end }}

{{/*
Validate values
*/}}
{{- define "n8n.validate" -}}
{{- if and (ne .Values.database.type "sqlite") (ne .Values.database.type "postgresdb") -}}
{{- fail (printf "database.type must be 'sqlite' or 'postgresdb', got '%s'" .Values.database.type) -}}
{{- end -}}
{{- if and (ne .Values.runners.mode "internal") (ne .Values.runners.mode "external") -}}
{{- fail (printf "runners.mode must be 'internal' or 'external', got '%s'" .Values.runners.mode) -}}
{{- end -}}
{{- if and .Values.webhook.enabled (not (include "n8n.isQueueMode" .)) -}}
{{- fail "webhook.enabled=true requires worker.replicas > 0" -}}
{{- end -}}
{{- if and (include "n8n.isQueueMode" .) (eq .Values.database.type "sqlite") -}}
{{- fail "worker.replicas > 0 requires database.type=postgresdb" -}}
{{- end -}}
{{- if and (include "n8n.needsRedis" .) (not .Values.redis.enabled) (not .Values.externalRedis.host) -}}
{{- fail "Workers and webhook processors require Redis. Set redis.enabled=true or configure externalRedis.host" -}}
{{- end -}}
{{- if and (eq .Values.database.type "postgresdb") (not .Values.database.postgresdb.host) -}}
{{- fail "database.postgresdb.host is required when database.type=postgresdb" -}}
{{- end -}}
{{- if and (eq .Values.database.type "postgresdb") (not .Values.database.postgresdb.existingSecret) (not .Values.database.postgresdb.password) -}}
{{- fail "database.postgresdb.password or database.postgresdb.existingSecret is required when database.type=postgresdb" -}}
{{- end -}}
{{- if and (eq .Values.database.type "postgresdb") .Values.database.postgresdb.password .Values.database.postgresdb.existingSecret -}}
{{- fail "database.postgresdb.password and database.postgresdb.existingSecret are mutually exclusive. Use one or the other" -}}
{{- end -}}
{{- if and .Values.redis.enabled .Values.externalRedis.host -}}
{{- fail "redis.enabled=true and externalRedis.host are mutually exclusive. Use one or the other" -}}
{{- end -}}
{{- if and .Values.externalRedis.host (not .Values.externalRedis.password) (not .Values.externalRedis.existingSecret) -}}
{{- fail "externalRedis.host is set but no authentication configured. Set externalRedis.password or externalRedis.existingSecret" -}}
{{- end -}}
{{- if and .Values.externalRedis.password .Values.externalRedis.existingSecret -}}
{{- fail "externalRedis.password and externalRedis.existingSecret are mutually exclusive. Use one or the other" -}}
{{- end -}}
{{- if and (eq .Values.runners.mode "external") (not .Values.runners.authToken) -}}
{{- fail "runners.authToken is required when runners.mode=external" -}}
{{- end -}}
{{- if and .Values.persistence.enabled (include "n8n.isQueueMode" .) -}}
{{- fail "persistence.enabled=true is not supported with workers. Use externalStorage.s3 for binary data persistence" -}}
{{- end -}}
{{- if and .Values.externalStorage.s3.enabled (not .Values.externalStorage.s3.host) -}}
{{- fail "externalStorage.s3.host is required when externalStorage.s3.enabled=true" -}}
{{- end -}}
{{- if and .Values.externalStorage.s3.enabled (not .Values.externalStorage.s3.bucketName) -}}
{{- fail "externalStorage.s3.bucketName is required when externalStorage.s3.enabled=true" -}}
{{- end -}}
{{- if and .Values.externalStorage.s3.enabled (not .Values.externalStorage.s3.bucketRegion) -}}
{{- fail "externalStorage.s3.bucketRegion is required when externalStorage.s3.enabled=true" -}}
{{- end -}}
{{- if and .Values.externalStorage.s3.enabled (not .Values.externalStorage.s3.existingSecret) (or (not .Values.externalStorage.s3.accessKey) (not .Values.externalStorage.s3.accessSecret)) -}}
{{- fail "externalStorage.s3.accessKey and externalStorage.s3.accessSecret (or externalStorage.s3.existingSecret) are required when externalStorage.s3.enabled=true" -}}
{{- end -}}
{{- if and .Values.externalStorage.s3.enabled .Values.externalStorage.s3.accessKey .Values.externalStorage.s3.existingSecret -}}
{{- fail "externalStorage.s3.accessKey/accessSecret and externalStorage.s3.existingSecret are mutually exclusive. Use one or the other" -}}
{{- end -}}
{{- if and (gt (int .Values.main.replicas) 1) (not (include "n8n.isQueueMode" .)) -}}
{{- fail "main.replicas > 1 requires worker.replicas > 0 (multi-main needs PostgreSQL + Redis)" -}}
{{- end -}}
{{- end -}}

{{/*
Common environment variables for all n8n containers
*/}}
{{- define "n8n.env" -}}
- name: N8N_PORT
  value: "5678"
- name: DB_TYPE
  value: {{ .Values.database.type | quote }}
{{- if eq .Values.database.type "postgresdb" }}
- name: DB_POSTGRESDB_HOST
  value: {{ .Values.database.postgresdb.host | quote }}
- name: DB_POSTGRESDB_PORT
  value: {{ .Values.database.postgresdb.port | quote }}
- name: DB_POSTGRESDB_DATABASE
  value: {{ .Values.database.postgresdb.database | quote }}
- name: DB_POSTGRESDB_USER
  value: {{ .Values.database.postgresdb.user | quote }}
- name: DB_POSTGRESDB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "n8n.database.secretName" . }}
      key: {{ include "n8n.database.secretKey" . }}
{{- end }}
{{- if include "n8n.isQueueMode" . }}
- name: EXECUTIONS_MODE
  value: "queue"
{{- end }}
{{- if or (include "n8n.isQueueMode" .) (eq .Values.runners.mode "external") }}
- name: N8N_RUNNERS_ENABLED
  value: "true"
- name: N8N_RUNNERS_MODE
  value: {{ .Values.runners.mode | quote }}
{{- end }}
{{- if include "n8n.needsRedis" . }}
- name: QUEUE_BULL_REDIS_HOST
  value: {{ include "n8n.redis.host" . | quote }}
- name: QUEUE_BULL_REDIS_PORT
  value: {{ include "n8n.redis.port" . | quote }}
{{- if include "n8n.redis.hasAuth" . }}
- name: QUEUE_BULL_REDIS_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "n8n.redis.secretName" . }}
      key: {{ include "n8n.redis.secretKey" . }}
{{- end }}
{{- end }}
{{- if .Values.webhook.enabled }}
{{- $webhookUrl := .Values.webhook.url -}}
{{- if and (not $webhookUrl) .Values.ingress.enabled (gt (len .Values.ingress.hosts) 0) -}}
{{- $webhookUrl = printf "https://%s" (index .Values.ingress.hosts 0).host -}}
{{- end }}
{{- if $webhookUrl }}
- name: WEBHOOK_URL
  value: {{ $webhookUrl | quote }}
{{- end }}
{{- end }}
{{- if gt (int .Values.main.replicas) 1 }}
- name: N8N_MULTI_MAIN_SETUP_ENABLED
  value: "true"
- name: N8N_MULTI_MAIN_SETUP_KEY_TTL
  value: {{ .Values.main.multiMain.ttl | quote }}
- name: N8N_MULTI_MAIN_SETUP_CHECK_INTERVAL
  value: {{ .Values.main.multiMain.checkInterval | quote }}
{{- end }}
{{- if .Values.externalStorage.s3.enabled }}
- name: N8N_AVAILABLE_BINARY_DATA_MODES
  value: "filesystem,s3"
- name: N8N_DEFAULT_BINARY_DATA_MODE
  value: "s3"
- name: N8N_EXTERNAL_STORAGE_S3_HOST
  value: {{ .Values.externalStorage.s3.host | quote }}
- name: N8N_EXTERNAL_STORAGE_S3_BUCKET_NAME
  value: {{ .Values.externalStorage.s3.bucketName | quote }}
- name: N8N_EXTERNAL_STORAGE_S3_BUCKET_REGION
  value: {{ .Values.externalStorage.s3.bucketRegion | quote }}
- name: N8N_EXTERNAL_STORAGE_S3_ACCESS_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "n8n.s3.secretName" . }}
      key: {{ include "n8n.s3.accessKeySecretKey" . }}
- name: N8N_EXTERNAL_STORAGE_S3_ACCESS_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ include "n8n.s3.secretName" . }}
      key: {{ include "n8n.s3.accessSecretSecretKey" . }}
{{- end }}
{{- end -}}

{{/*
Common envFrom for all n8n containers
*/}}
{{- define "n8n.envFrom" -}}
- configMapRef:
    name: {{ include "n8n.fullname" . }}
{{- if .Values.secret }}
- secretRef:
    name: {{ include "n8n.fullname" . }}
{{- end }}
{{- end -}}

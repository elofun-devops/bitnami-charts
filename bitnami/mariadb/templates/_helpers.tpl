{{/* vim: set filetype=mustache: */}}

{{- define "mariadb.primary.fullname" -}}
{{- if eq .Values.architecture "replication" }}
{{- printf "%s-%s" (include "common.names.fullname" .) .Values.primary.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- include "common.names.fullname" . -}}
{{- end -}}
{{- end -}}

{{- define "mariadb.secondary.fullname" -}}
{{- printf "%s-%s" (include "common.names.fullname" .) .Values.secondary.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Return the proper MariaDB image name
*/}}
{{- define "mariadb.image" -}}
{{ include "common.images.image" (dict "imageRoot" .Values.image "global" .Values.global) }}
{{- end -}}

{{/*
Return the proper metrics image name
*/}}
{{- define "mariadb.metrics.image" -}}
{{ include "common.images.image" (dict "imageRoot" .Values.metrics.image "global" .Values.global) }}
{{- end -}}

{{/*
Return the proper image name (for the init container volume-permissions image)
*/}}
{{- define "mariadb.volumePermissions.image" -}}
{{ include "common.images.image" (dict "imageRoot" .Values.volumePermissions.image "global" .Values.global) }}
{{- end -}}

{{/*
Return the proper Docker Image Registry Secret Names
*/}}
{{- define "mariadb.imagePullSecrets" -}}
{{ include "common.images.pullSecrets" (dict "images" (list .Values.image .Values.metrics.image .Values.volumePermissions.image) "global" .Values.global) }}
{{- end -}}

{{ template "mariadb.initdbScriptsCM" . }}
{{/*
Get the initialization scripts ConfigMap name.
*/}}
{{- define "mariadb.initdbScriptsCM" -}}
{{- if .Values.initdbScriptsConfigMap -}}
{{- printf "%s" .Values.initdbScriptsConfigMap -}}
{{- else -}}
{{- printf "%s-init-scripts" (include "mariadb.primary.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "mariadb.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
    {{ default (include "common.names.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Return the configmap with the MariaDB Primary configuration
*/}}
{{- define "mariadb.primary.configmapName" -}}
{{- if .Values.primary.existingConfigmap -}}
    {{- printf "%s" (tpl .Values.primary.existingConfigmap $) -}}
{{- else -}}
    {{- printf "%s" (include "mariadb.primary.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Return true if a configmap object should be created for MariaDB Secondary
*/}}
{{- define "mariadb.primary.createConfigmap" -}}
{{- if and .Values.primary.configuration (not .Values.primary.existingConfigmap) }}
    {{- true -}}
{{- else -}}
{{- end -}}
{{- end -}}

{{/*
Return the configmap with the MariaDB Primary configuration
*/}}
{{- define "mariadb.secondary.configmapName" -}}
{{- if .Values.secondary.existingConfigmap -}}
    {{- printf "%s" (tpl .Values.secondary.existingConfigmap $) -}}
{{- else -}}
    {{- printf "%s" (include "mariadb.secondary.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Return true if a configmap object should be created for MariaDB Secondary
*/}}
{{- define "mariadb.secondary.createConfigmap" -}}
{{- if and (eq .Values.architecture "replication") .Values.secondary.configuration (not .Values.secondary.existingConfigmap) }}
    {{- true -}}
{{- else -}}
{{- end -}}
{{- end -}}

{{/*
Return the secret with MariaDB credentials
*/}}
{{- define "mariadb.secretName" -}}
    {{- if .Values.auth.existingSecret -}}
        {{- printf "%s" .Values.auth.existingSecret -}}
    {{- else -}}
        {{- printf "%s" (include "common.names.fullname" .) -}}
    {{- end -}}
{{- end -}}

{{/*
Return true if a secret object should be created for MariaDB
*/}}
{{- define "mariadb.createSecret" -}}
{{- if not (or .Values.auth.existingSecret .Values.auth.customPasswordFiles) }}
    {{- true -}}
{{- end -}}
{{- end -}}

{{/*
Compile all warnings into a single message, and call fail.
*/}}
{{- define "mariadb.validateValues" -}}
{{- $messages := list -}}
{{- $messages := append $messages (include "mariadb.validateValues.architecture" .) -}}
{{- $messages := without $messages "" -}}
{{- $message := join "\n" $messages -}}

{{- if $message -}}
{{-   printf "\nVALUES VALIDATION:\n%s" $message | fail -}}
{{- end -}}
{{- end -}}

{{/* Validate values of MariaDB - must provide a valid architecture */}}
{{- define "mariadb.validateValues.architecture" -}}
{{- if and (ne .Values.architecture "standalone") (ne .Values.architecture "replication") -}}
mariadb: architecture
    Invalid architecture selected. Valid values are "standalone" and
    "replication". Please set a valid architecture (--set architecture="xxxx")
{{- end -}}
{{- end -}}

{{- define "mariadb.rootPassword" -}}
{{- $pwd := include "mariadb.generateRootPassword" . }}
{{- include "helm.kv.getOrSet" (dict "context" $ "key" (printf "%s.mariadb.rootPassword" .Release.FullName) "value" $pwd) -}}
{{- end -}}

{{- define "mariadb.generateRootPassword" -}}
{{- if (not .Values.auth.forcePassword) }}
{{- $pwd := include "common.secrets.passwords.manage" (dict "secret" (include "common.names.fullname" .) "key" "mariadb-root-password" "providedValues" (list "auth.rootPassword") "context" $) }}
{{- include "helm.values.unquote" $pwd | b64dec }}
{{- else }}
{{- required "A MariaDB Root Password is required!" .Values.auth.rootPassword }}
{{- end }}
{{- end -}}

{{- define "mariadb.password" -}}
{{- $pwd := include "mariadb.generatePassword" . }}
{{- include "helm.kv.getOrSet" (dict "context" $ "key" (printf "%s.mariadb.password" .Release.FullName) "value" $pwd) -}}
{{- end -}}

{{- define "mariadb.generatePassword" -}}
{{- if (not .Values.auth.forcePassword) }}
{{- $pwd := include "common.secrets.passwords.manage" (dict "secret" (include "common.names.fullname" .) "key" "mariadb-password" "providedValues" (list "auth.password") "context" $) }}
{{- include "helm.values.unquote" $pwd | b64dec }}
{{- else }}
{{- required "A MariaDB Database Password is required!" .Values.auth.password }}
{{- end }}
{{- end -}}

{{- define "mariadb.replicationPassword" -}}
{{- $pwd := include "mariadb.generateReplicationPassword" . }}
{{- include "helm.kv.getOrSet" (dict "context" $ "key" (printf "%s.mariadb.replicationPassword" .Release.FullName) "value" $pwd) -}}
{{- end -}}

{{- define "mariadb.generateReplicationPassword" -}}
{{- if (not .Values.auth.forcePassword) }}
{{- $pwd := include "common.secrets.passwords.manage" (dict "secret" (include "common.names.fullname" .) "key" "mariadb-replication-password" "providedValues" (list "auth.replicationPassword") "context" $) }}
{{- include "helm.values.unquote" $pwd | b64dec }}
{{- else }}
{{- required "A MariaDB Replication Password is required!" .Values.auth.replicationPassword }}
{{- end }}
{{- end -}}

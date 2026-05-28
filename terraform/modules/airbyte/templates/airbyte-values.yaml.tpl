# airbyte-values.yaml.tpl
# Helm values file for the Airbyte chart (v2.x / abctl local install).
# Rendered by templatefile() in main.tf and delivered to the instance via an
# SSM SecureString parameter. All $${...} tokens are Terraform template
# variables injected at plan time -- they are not Helm-native anchors.
#
# Key decisions:
#   - Airbyte config DB and Temporal DB share the same RDS instance but use
#     separate named databases for isolation.
#   - S3 is used for connector logs, state payloads, and workload output
#     instead of the default local PVC storage.
#   - secretsManager.type = VAULT is NOT used; Airbyte stores connector
#     credentials in AWS Secrets Manager directly via the IAM role on the
#     instance profile.
#   - Auth is enabled. For an HTTP (non-TLS) deployment accessed via bare IP,
#     we MUST: disable cookieSecureSetting so the browser keeps the
#     refresh-token cookie on HTTP, and relax cookieSameSiteSetting from
#     Strict to Lax so the cookie is sent on the post-login redirect that
#     bootstraps the session. Without these, the webapp posts an empty body to
#     /api/oauth/access_token and React loops with "Maximum update depth
#     exceeded".

global:
  auth:
    enabled: true

    # Security settings for the auth subsystem.
    # cookieSecureSetting=false is REQUIRED for HTTP deployments; otherwise
    # the browser drops the access/refresh cookies because they carry the
    # Secure flag, and /api/oauth/access_token receives an empty body.
    # cookieSameSiteSetting=Lax is required because the chart default Strict
    # blocks the cookie on the cross-context redirect that completes login.
    # Lax is the standard relaxation; do NOT set None without HTTPS, browsers
    # will reject SameSite=None;Secure=false combinations outright.
    security:
      cookieSecureSetting: "false"
      cookieSameSiteSetting: "Lax"

  database:
    # External RDS PostgreSQL for Airbyte configuration storage.
    type: "external"
    host: "${db_host}"
    port: ${db_port}
    database: "${db_name}"
    user: "${db_user}"
    password: "${db_password}"

  # Airbyte workload storage backend: S3 instead of ephemeral PVCs.
  storage:
    type: S3
    storageSecretName: ""  # IAM role on instance profile provides credentials.
    bucket:
      log: "${s3_bucket_name}"
      state: "${s3_bucket_name}"
      workloadOutput: "${s3_bucket_name}"
    s3:
      region: "${s3_region}"
      authenticationType: instanceProfile

# NOTE: temporal.database key path must be verified against the chart version
# installed by abctl v0.30.4. In Airbyte chart v2.x the Temporal DB is
# configured via global.database. If this block has no effect, remove it.
temporal:
  database:
    # Temporal requires its own named database on the same RDS instance.
    host: "${temporal_db_host}"
    port: ${temporal_db_port}
    database: "${temporal_db_name}"
    user: "${temporal_db_user}"
    password: "${temporal_db_password}"

# Disable internal MinIO; all blob storage goes through S3 above.
minio:
  enabled: false

# Webapp service port; actual HTTP exposure is handled by ingress-nginx below.
webapp:
  service:
    port: 80

# Disable internal PostgreSQL; using external RDS above.
postgresql:
  enabled: false

server:
  extraEnv:
    - name: AWS_DEFAULT_REGION
      value: "${s3_region}"

worker:
  extraEnv:
    - name: AWS_DEFAULT_REGION
      value: "${s3_region}"

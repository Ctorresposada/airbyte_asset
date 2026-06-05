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
#   - Auth is enabled. HTTPS is terminated at the ALB; cookieSameSiteSetting is
#     set to Lax (see comment below) to fix the OAuth redirect flow.

global:
  airbyteUrl: "${airbyte_url}"

  auth:
    enabled: true
 
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
  # ARM64 (Graviton) digest -- linux/arm64
  image:
    tag: 1.27.2@sha256:f0e58af3ce668fa7ce162f327c1785efe625cb754c0e508a37300f275981414e
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
  # ARM64 (Graviton) digest -- linux/arm64
  image:
    tag: 2.1.0@sha256:9b07db9a2b32bb2a3ea65031c1ecd438459134519d8940a7d521e75591ad5b40
  extraEnv:
    - name: AWS_DEFAULT_REGION
      value: "${s3_region}"

worker:
  # ARM64 (Graviton) digest -- linux/arm64
  image:
    tag: 2.1.0@sha256:1598f87d6036f9217b571854c09d1f11522341cdb08273807ec1b1a00f64baee
  extraEnv:
    - name: AWS_DEFAULT_REGION
      value: "${s3_region}"

workloadLauncher:
  # ARM64 (Graviton) digest -- linux/arm64
  image:
    tag: 2.1.0@sha256:729a413e4f54c6a738ab918b7f969be6f01be3f776a4206d3961d85e9403f578
  extraEnv:
    - name: AWS_DEFAULT_REGION
      value: "${s3_region}"

workloadApiServer:
  # ARM64 (Graviton) digest -- linux/arm64
  image:
    tag: 2.1.0@sha256:cc1c33613dd30c8c34151b6b00e23952499fd6bdbd82267bca7ca52a1aff7b28
  extraEnv:
    - name: AWS_DEFAULT_REGION
      value: "${s3_region}"

manifestServer:
  # ARM64 (Graviton) digest -- linux/arm64
  image:
    tag: 7.10.0@sha256:19e620b3e2f9de6f3fcc34d6c9b7a9bd4028162e005b357f32aea12e49f6b461
  extraEnv:
    - name: AWS_DEFAULT_REGION
      value: "${s3_region}"

cron:
  # ARM64 (Graviton) digest -- linux/arm64
  image:
    tag: 2.1.0@sha256:86fa1c563bb8fb533adff0f1967914e8449e0d261ed9b06411b03de148e1dc30
  extraEnv:
    - name: AWS_DEFAULT_REGION
      value: "${s3_region}"

airbyteBootloader:
  # ARM64 (Graviton) digest -- linux/arm64
  image:
    tag: 2.1.0@sha256:37a699e07e3694828a8597f54c1e9c7e2f5c9c990c28bf628f025ef41954a7e4

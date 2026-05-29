# Current region resolved for use in the S3 destination configuration.
data "aws_region" "current" {
  count = var.create ? 1 : 0
}

# ---------------------------------------------------------------------------
# Secrets Manager secret versions for source credentials.
# Each is gated on var.create so the stack can be soft-deleted without
# requiring the secrets to exist.
# ---------------------------------------------------------------------------

# AWS credentials consumed by the Airbyte S3 destination connector.
data "aws_secretsmanager_secret_version" "s3_credentials" {
  count = var.create ? 1 : 0

  secret_id = var.s3_credentials_secret_id
}

# Oracle DB credentials consumed by the Airbyte Oracle source connector.
data "aws_secretsmanager_secret_version" "oracle_credentials" {
  count = var.create ? 1 : 0

  secret_id = var.oracle_credentials_secret_id
}

#data "aws_secretsmanager_secret_version" "mssql" {
#  count = var.create ? 1 : 0
#
#  secret_id = var.mssql_secret_arn
#}
#
#data "aws_secretsmanager_secret_version" "google_drive" {
#  count = var.create ? 1 : 0
#
#  secret_id = var.google_drive_secret_arn
#}
#
#data "aws_secretsmanager_secret_version" "docebo" {
#  count = var.create ? 1 : 0
#
#  secret_id = var.docebo_secret_arn
#}

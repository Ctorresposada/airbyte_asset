# ---------------------------------------------------------------------------
# Secrets Manager Secret for Airbyte Cloud: stores Airbyte IAM credentials
# ---------------------------------------------------------------------------
resource "aws_secretsmanager_secret" "airbyte_credentials" {
  #checkov:skip=CKV2_AWS_57: Automatic rotation requires Lambda or manual change, for now leaving as static in DEV
  name                    = "airbyte/client-credentials"
  description             = "Airbyte Cloud IAM access key and secret for data ingestion"
  kms_key_id              = aws_kms_key.airbyte[0].arn
  recovery_window_in_days = 14

  tags = merge(var.tags, { Name = "${local.name}-airbyte-credentials" })
}

# ---------------------------------------------------------------------------
# Secret Version: populates the secret with the IAM access key values
# ---------------------------------------------------------------------------
resource "aws_secretsmanager_secret_version" "airbyte_credentials" {
  secret_id = aws_secretsmanager_secret.airbyte_credentials.id
  secret_string = jsonencode({
    access_key_id     = aws_iam_access_key.airbyte.id
    secret_access_key = aws_iam_access_key.airbyte.secret
  })
}


resource "aws_secretsmanager_secret" "airbyte_oracle_credentials" {
  #checkov:skip=CKV2_AWS_57: Automatic rotation requires Lambda or manual change, for now leaving as static in DEV
  name                    = "airbyte/oracle-credentials"
  description             = "Oracle DB authentication details for data ingestion"
  kms_key_id              = aws_kms_key.airbyte[0].arn
  recovery_window_in_days = 14

  tags = merge(var.tags, { Name = "${local.name}-airbyte-oracle-credentials" })
}

# ---------------------------------------------------------------------------
# Secrets Manager Policy: restricted access to the secret
# Only the Airbyte IAM user and the root account can read it
# ---------------------------------------------------------------------------
resource "aws_secretsmanager_secret_policy" "airbyte_credentials" {
  secret_arn = aws_secretsmanager_secret.airbyte_credentials.arn
  policy     = local.airbyte_secret_policy
}

resource "aws_secretsmanager_secret_policy" "airbyte_oracle_credentials" {
  secret_arn = aws_secretsmanager_secret.airbyte_oracle_credentials.arn
  policy     = local.airbyte_secret_policy
}


resource "aws_secretsmanager_secret" "airbyte_google_drive_credentials" {
  #checkov:skip=CKV2_AWS_57: Automatic rotation requires Lambda or manual change, for now leaving as static in DEV
  name                    = "airbyte/google-drive-credentials"
  description             = "Google service account JSON for Google Drive data ingestion"
  kms_key_id              = aws_kms_key.airbyte[0].arn
  recovery_window_in_days = 14

  tags = merge(var.tags, { Name = "${local.name}-airbyte-google-drive-credentials" })
}

resource "aws_secretsmanager_secret_policy" "airbyte_google_drive_credentials" {
  secret_arn = aws_secretsmanager_secret.airbyte_google_drive_credentials.arn
  policy     = local.airbyte_secret_policy
}



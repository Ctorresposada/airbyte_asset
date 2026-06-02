# ---------------------------------------------------------------------------
# Secrets Manager Secret: Google Drive service account JSON
#
# The secret value is a PLACEHOLDER — populate it manually after apply:
#
#   aws secretsmanager put-secret-value \
#     --secret-id gdrive/tea-service-account \
#     --secret-string file://tea.json \
#     --profile dev-data-engineer
#
# The JSON must be a standard Google service account key file with
# Drive API (read-only) scope. The service account must be shared on
# (or have domain-wide delegation for) the TEA Drive folder.
# ---------------------------------------------------------------------------
resource "aws_secretsmanager_secret" "gdrive_sa" {
  #checkov:skip=CKV_AWS_149: KMS CMK not required — consistent with CKV_AWS_145 project decision
  #checkov:skip=CKV2_AWS_57: Automatic rotation not applicable — Google SA JSON rotated manually via key lifecycle process
  count = var.create ? 1 : 0

  name                    = "gdrive/tea-service-account"
  description             = "Google Drive service account JSON for TEA folder → S3 raw landing zone sync"
  recovery_window_in_days = 14

  tags = merge(var.tags, { Name = "${local.name}-gdrive-tea-sa" })
}

resource "aws_secretsmanager_secret_version" "gdrive_sa_placeholder" {
  count = var.create ? 1 : 0

  secret_id     = aws_secretsmanager_secret.gdrive_sa[0].id
  secret_string = jsonencode({ placeholder = "REPLACE_WITH_GOOGLE_SA_JSON" })

  # Prevent Terraform from overwriting the real secret after manual population
  lifecycle {
    ignore_changes = [secret_string]
  }
}

# ---------------------------------------------------------------------------
# SSM Parameter: cursor for incremental sync (managed by Lambda at runtime)
# Seeded to epoch so the first run is a full refresh.
# ---------------------------------------------------------------------------
resource "aws_ssm_parameter" "gdrive_sync_cursor" {
  #checkov:skip=CKV2_AWS_34: Cursor holds a non-sensitive ISO-8601 timestamp; encryption not required
  count = var.create ? 1 : 0

  name        = "/r20/gdrive-sync/last-sync-time"
  description = "ISO-8601 timestamp of the last successful gdrive → S3 sync run"
  type        = "String"
  value       = "1970-01-01T00:00:00+00:00"

  # Lambda owns this value at runtime; Terraform only seeds it
  lifecycle {
    ignore_changes = [value]
  }

  tags = merge(var.tags, { Name = "${local.name}-gdrive-sync-cursor" })
}

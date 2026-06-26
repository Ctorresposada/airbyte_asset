# ---------------------------------------------------------------------------
# S3 Data Lake destination
# ---------------------------------------------------------------------------

resource "airbyte_destination" "s3" {
  count = var.create_s3_destination ? 1 : 0

  name          = var.s3_destination_name
  workspace_id  = var.workspace_id
  definition_id = "4816b78f-1489-44c1-9060-4b19d5fa9571" # S3 destination

  configuration = jsonencode(merge(
    {
      s3_bucket_name   = var.s3_bucket_name
      s3_bucket_path   = var.s3_bucket_path
      s3_bucket_region = var.s3_bucket_region
      format = {
        format_type = var.s3_format
      }
    },
    # Only include credentials if provided; omit to use instance profile.
    var.s3_access_key_id != "" ? {
      access_key_id     = var.s3_access_key_id
      secret_access_key = var.s3_secret_access_key
    } : {}
  ))
}

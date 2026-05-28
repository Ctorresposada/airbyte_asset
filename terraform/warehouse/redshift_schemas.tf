# ---------------------------------------------------------------------------
# Redshift Serverless schemas — R2EP2IC-34
#
# Creates three schemas inside the `gold` database via the Redshift Data API
# (no direct network access to Redshift required):
#   - bronze : Spectrum external schema → Glue bronze catalog
#   - silver : Spectrum external schema → Glue silver catalog
#   - gold   : native Redshift schema for dbt gold-layer tables
#
# Re-applying is safe: every statement uses IF NOT EXISTS.
# Triggers re-run if the workgroup, IAM role, or Glue DB names change.
# ---------------------------------------------------------------------------

resource "null_resource" "redshift_schemas" {
  count = var.create ? 1 : 0

  triggers = {
    workgroup_name = aws_redshiftserverless_workgroup.this[0].workgroup_name
    database       = var.redshift_db_name
    glue_bronze_db = var.glue_bronze_db_name
    glue_silver_db = var.glue_silver_db_name
    iam_role_arn   = aws_iam_role.redshift_serverless[0].arn
    aws_region     = var.aws_region
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    # In HCL heredocs, only ${...} needs escaping ($${...} for a literal ${}).
    # Plain $var and $(cmd) are passed through as-is to the shell.
    command = <<-EOT
      set -euo pipefail

      # The local-exec runner uses the base OIDC credentials (tooling account).
      # Assume the target-account execution role so Redshift Data API calls
      # reach the correct account (${var.account_id}).
      echo "==> Assuming execution role in account ${var.account_id}"
      CREDS=$(aws sts assume-role \
        --role-arn 'arn:aws:iam::${var.account_id}:role/region-20-terraform-execution-role' \
        --role-session-name 'terraform-redshift-schema-setup' \
        --output json)
      export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | jq -r '.Credentials.AccessKeyId')
      export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | jq -r '.Credentials.SecretAccessKey')
      export AWS_SESSION_TOKEN=$(echo "$CREDS" | jq -r '.Credentials.SessionToken')
      echo "  assumed role ok"

      run_sql() {
        local sql="$1"
        local stmt_id
        echo "  executing: $sql"
        stmt_id=$(aws redshift-data execute-statement \
          --workgroup-name '${aws_redshiftserverless_workgroup.this[0].workgroup_name}' \
          --database '${var.redshift_db_name}' \
          --region '${var.aws_region}' \
          --sql "$sql" \
          --query Id --output text)
        echo "  statement_id=$stmt_id"
        for attempt in $(seq 40); do
          status=$(aws redshift-data describe-statement \
            --id "$stmt_id" \
            --region '${var.aws_region}' \
            --query Status --output text)
          echo "  attempt=$attempt status=$status"
          [ "$status" = "FINISHED" ] && return 0
          if [ "$status" = "FAILED" ] || [ "$status" = "ABORTED" ]; then
            aws redshift-data describe-statement --id "$stmt_id" --region '${var.aws_region}' >&2
            return 1
          fi
          sleep 3
        done
        echo "Timeout waiting for statement $stmt_id" >&2
        return 1
      }

      echo "==> Creating Spectrum external schema: bronze"
      run_sql "CREATE EXTERNAL SCHEMA IF NOT EXISTS bronze FROM DATA CATALOG DATABASE '${var.glue_bronze_db_name}' IAM_ROLE '${aws_iam_role.redshift_serverless[0].arn}' REGION '${var.aws_region}'"

      echo "==> Creating Spectrum external schema: silver"
      run_sql "CREATE EXTERNAL SCHEMA IF NOT EXISTS silver FROM DATA CATALOG DATABASE '${var.glue_silver_db_name}' IAM_ROLE '${aws_iam_role.redshift_serverless[0].arn}' REGION '${var.aws_region}'"

      echo "==> Creating native schema: gold"
      run_sql "CREATE SCHEMA IF NOT EXISTS gold"

      echo "All schemas created successfully."
    EOT
  }

  depends_on = [
    aws_redshiftserverless_workgroup.this,
    aws_iam_role.redshift_serverless,
  ]
}

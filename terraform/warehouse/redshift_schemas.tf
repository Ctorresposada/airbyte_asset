# ---------------------------------------------------------------------------
# Redshift Serverless schemas — R2EP2IC-34
#
# Creates three schemas inside the `gold` database via the Redshift Data API
# (no direct network access to Redshift required):
#   - bronze : Spectrum external schema → Glue bronze catalog
#   - silver : Spectrum external schema → Glue silver catalog
#   - gold   : native Redshift schema for dbt gold-layer tables
#
# Re-applying is safe: schema statements use IF NOT EXISTS.
# Triggers re-run if the workgroup, IAM role, or Glue DB names change.
# ---------------------------------------------------------------------------

resource "null_resource" "redshift_schemas" {
  count = var.create ? 1 : 0

  triggers = {
    workgroup_name   = aws_redshiftserverless_workgroup.this[0].workgroup_name
    database         = var.redshift_db_name
    glue_bronze_db   = var.glue_bronze_db_name
    glue_silver_db   = var.glue_silver_db_name
    iam_role_arn     = aws_iam_role.redshift_serverless[0].arn
    aws_region       = var.aws_region
    schemas_revision = "2"
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
        for attempt in $(seq 200); do
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

      echo "All schemas applied successfully."
    EOT
  }

  depends_on = [
    aws_redshiftserverless_workgroup.this,
    aws_iam_role.redshift_serverless,
  ]
}

# ---------------------------------------------------------------------------
# dbt Core service user — R2EP2IC-34
#
# Provisions the dbt Core service user (var.dbt_redshift_user) for IAM-brokered
# passwordless auth: the user is created with PASSWORD DISABLE so it is reachable
# only via redshift-serverless:GetCredentials (the transformations task role vends
# a short-lived password at connection time — no static secret).
# Grants follow least privilege: USAGE+CREATE+ALL on gold (dbt builds models
# there), USAGE+SELECT on the bronze/silver Spectrum schemas (read-only source).
#
# Depends on null_resource.redshift_schemas: the gold/bronze/silver schemas must
# exist before the user can be granted privileges on them.
#
# Re-applying is safe: CREATE USER is guarded by a pg_user existence pre-check
# (Redshift has no CREATE USER IF NOT EXISTS). GRANT statements are naturally
# idempotent. A separate null_resource runs in its own shell, so the assume-role
# bootstrap and run_sql helper are re-established here rather than shared.
# Triggers re-run if the workgroup, database, or dbt user change.
# ---------------------------------------------------------------------------

resource "null_resource" "redshift_dbt_service_user" {
  count = var.create ? 1 : 0

  triggers = {
    workgroup_name     = aws_redshiftserverless_workgroup.this[0].workgroup_name
    database           = var.redshift_db_name
    aws_region         = var.aws_region
    dbt_user           = var.dbt_redshift_user
    dbt_task_role_name = var.dbt_task_role_name
    # Bump this value whenever you need to force the grants to re-run
    # (e.g. after the gold schema or dbt_service user is recreated).
    # Normal operations never require a re-run — grants persist in Redshift.
    grants_revision = "3"
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
        --role-session-name 'terraform-redshift-dbt-user-setup' \
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
        for attempt in $(seq 200); do
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

      # Redshift has no CREATE USER IF NOT EXISTS, so query the result of a
      # pg_user existence check before issuing CREATE USER. run_sql only waits
      # for FINISHED; this helper additionally fetches the scalar result.
      user_exists() {
        local stmt_id exists
        stmt_id=$(aws redshift-data execute-statement \
          --workgroup-name '${aws_redshiftserverless_workgroup.this[0].workgroup_name}' \
          --database '${var.redshift_db_name}' \
          --region '${var.aws_region}' \
          --sql "SELECT 1 FROM pg_user WHERE usename = '${var.dbt_redshift_user}'" \
          --query Id --output text)
        for attempt in $(seq 200); do
          status=$(aws redshift-data describe-statement \
            --id "$stmt_id" \
            --region '${var.aws_region}' \
            --query Status --output text)
          [ "$status" = "FINISHED" ] && break
          if [ "$status" = "FAILED" ] || [ "$status" = "ABORTED" ]; then
            aws redshift-data describe-statement --id "$stmt_id" --region '${var.aws_region}' >&2
            return 2
          fi
          sleep 3
        done
        exists=$(aws redshift-data get-statement-result \
          --id "$stmt_id" \
          --region '${var.aws_region}' \
          --query 'length(Records)' --output text)
        [ "$exists" != "0" ]
      }

      echo "==> Ensuring dbt service user exists: ${var.dbt_redshift_user}"
      if user_exists; then
        echo "  user ${var.dbt_redshift_user} already exists, skipping CREATE USER"
      else
        echo "  creating user ${var.dbt_redshift_user} (PASSWORD DISABLE — IAM-only)"
        run_sql "CREATE USER ${var.dbt_redshift_user} PASSWORD DISABLE"
      fi

      echo "==> Granting privileges to IAMR:${var.dbt_task_role_name}"
      # Redshift Serverless GetCredentials maps the ECS task IAM role to a database
      # user named IAMR:<role-name>. The dbt profile's user field is overwritten by
      # the GetCredentials response, so grants must target this IAM-derived user.
      # gold: dbt builds models here — needs schema usage, object creation, and full DML.
      run_sql "GRANT USAGE ON SCHEMA gold TO \"IAMR:${var.dbt_task_role_name}\""
      run_sql "GRANT CREATE ON SCHEMA gold TO \"IAMR:${var.dbt_task_role_name}\""
      run_sql "GRANT ALL ON ALL TABLES IN SCHEMA gold TO \"IAMR:${var.dbt_task_role_name}\""
      run_sql "ALTER DEFAULT PRIVILEGES IN SCHEMA gold GRANT ALL ON TABLES TO \"IAMR:${var.dbt_task_role_name}\""

      # bronze/silver: read-only Spectrum sources for dbt staging models.
      run_sql "GRANT USAGE ON SCHEMA bronze TO \"IAMR:${var.dbt_task_role_name}\""
      run_sql "GRANT SELECT ON ALL TABLES IN SCHEMA bronze TO \"IAMR:${var.dbt_task_role_name}\""
      run_sql "GRANT USAGE ON SCHEMA silver TO \"IAMR:${var.dbt_task_role_name}\""
      run_sql "GRANT SELECT ON ALL TABLES IN SCHEMA silver TO \"IAMR:${var.dbt_task_role_name}\""

      echo "dbt service user and grants applied successfully."
    EOT
  }

  depends_on = [
    null_resource.redshift_schemas,
  ]
}

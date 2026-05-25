# ---------------------------------------------------------------------------
# Lake Formation: admin settings, S3 location registration, Airbyte grants
# Ticket: R2EP2IC-45
# ---------------------------------------------------------------------------

# Look up the Terraform execution role so it is registered as an LF admin.
# Without this, Terraform loses the ability to manage subsequent LF resources.
data "aws_iam_role" "terraform_execution" {
  count = var.create ? 1 : 0
  name  = var.lakeformation_terraform_role_name
}

# ---------------------------------------------------------------------------
# Data lake settings: set admins and preserve IAMAllowedPrincipals defaults.
#
# IAMAllowedPrincipals default grants are kept intentionally so that existing
# IAM-based access (Athena workgroups, Airbyte, Redshift Spectrum) continues
# to work. Remove these blocks and re-apply only after all principals have
# explicit LF grants in place.
# ---------------------------------------------------------------------------
resource "aws_lakeformation_data_lake_settings" "this" {
  count = var.create ? 1 : 0

  admins = concat(
    [data.aws_iam_role.terraform_execution[0].arn],
    var.lakeformation_admin_arns
  )

  create_database_default_permissions {
    permissions = ["ALL"]
    principal   = "IAM_ALLOWED_PRINCIPALS"
  }

  create_table_default_permissions {
    permissions = ["ALL"]
    principal   = "IAM_ALLOWED_PRINCIPALS"
  }
}

# ---------------------------------------------------------------------------
# Register bronze S3 path as a Lake Formation data lake location.
# Pre-requisite for granting DATA_LOCATION_ACCESS to any principal.
# ---------------------------------------------------------------------------
resource "aws_lakeformation_resource" "bronze" {
  count = var.create ? 1 : 0

  arn                     = aws_s3_bucket.buckets["bronze"].arn
  use_service_linked_role = true

  depends_on = [aws_lakeformation_data_lake_settings.this]
}

# ---------------------------------------------------------------------------
# Register silver S3 path as a Lake Formation data lake location.
# ---------------------------------------------------------------------------
resource "aws_lakeformation_resource" "silver" {
  count = var.create ? 1 : 0

  arn                     = aws_s3_bucket.buckets["silver"].arn
  use_service_linked_role = true

  depends_on = [aws_lakeformation_data_lake_settings.this]
}

# ---------------------------------------------------------------------------
# Grant Airbyte IAM user DATA_LOCATION_ACCESS on the bronze S3 location.
# Required so Airbyte can write Iceberg data files under the bronze prefix
# once Lake Formation governs that path.
# ---------------------------------------------------------------------------
resource "aws_lakeformation_permissions" "airbyte_bronze_location" {
  count = var.create ? 1 : 0

  principal = aws_iam_user.airbyte.arn

  data_location {
    arn = aws_s3_bucket.buckets["bronze"].arn
  }

  permissions = ["DATA_LOCATION_ACCESS"]

  depends_on = [aws_lakeformation_resource.bronze]
}

# ---------------------------------------------------------------------------
# Grant Airbyte IAM user CREATE_TABLE and DESCRIBE on the bronze Glue database.
# Allows Airbyte to register new Iceberg tables in the Glue Catalog.
# ---------------------------------------------------------------------------
resource "aws_lakeformation_permissions" "airbyte_bronze_database" {
  count = var.create ? 1 : 0

  principal = aws_iam_user.airbyte.arn

  database {
    name = aws_glue_catalog_database.databases["bronze"].name
  }

  permissions                   = ["CREATE_TABLE", "DESCRIBE"]
  permissions_with_grant_option = []

  depends_on = [aws_lakeformation_data_lake_settings.this]
}

# ---------------------------------------------------------------------------
# Grant lakeformation:GetDataAccess to all SSO roles that need Athena access.
#
# SSO reserved roles (/aws-reserved/sso.amazonaws.com/) are rejected by
# PutDataLakeSettings when added as LF admins. With IAMAllowedPrincipals:ALL
# defaults active, LF-level access is already granted to all IAM principals.
# The only missing piece is the IAM-level GetDataAccess permission, which
# allows Athena to call LF-vended credentials on behalf of the caller.
# An inline policy is the only Terraform-reachable path since the SSO
# permission sets live in a separate management account.
#
# Covered groups: Data Engineer (read/write), Analyst (read-only), Auditor (read-only).
# ---------------------------------------------------------------------------
locals {
  lf_athena_role_names = toset(concat(
    var.lakeformation_de_role_names,
    var.lakeformation_analyst_role_names,
    var.lakeformation_auditor_role_names,
  ))
}

resource "aws_iam_role_policy" "lakeformation_get_data_access" {
  for_each = var.create ? local.lf_athena_role_names : toset([])

  name = "lakeformation-get-data-access"
  role = each.value

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "lakeformation:GetDataAccess"
        Resource = "*"
      }
    ]
  })
}

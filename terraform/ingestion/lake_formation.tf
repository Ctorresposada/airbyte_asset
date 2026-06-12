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

  # create_database_default_permissions {
  #   permissions = ["ALL"]
  #   principal   = "IAM_ALLOWED_PRINCIPALS"
  # }

  # create_table_default_permissions {
  #   permissions = ["ALL"]
  #   principal   = "IAM_ALLOWED_PRINCIPALS"
  # }
}

# ---------------------------------------------------------------------------
# Register raw S3 path as a Lake Formation data lake location.
# Required so LF can vend S3 credentials to Athena for raw database queries.
# ---------------------------------------------------------------------------
resource "aws_lakeformation_resource" "raw" {
  count = var.create ? 1 : 0

  arn                     = aws_s3_bucket.buckets["raw"].arn
  use_service_linked_role = true

  depends_on = [aws_lakeformation_data_lake_settings.this]
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
# Grant DE SSO role DATA_LOCATION_ACCESS on the silver S3 location.
# Required for Athena to read Iceberg tables governed by Lake Formation:
# LF vends S3 credentials via the SLR only when the principal also has
# DATA_LOCATION_ACCESS — SELECT alone is insufficient for Iceberg reads.
# ---------------------------------------------------------------------------
resource "aws_lakeformation_permissions" "de_silver_location" {
  for_each = var.create ? toset(var.lakeformation_de_role_arns) : toset([])

  principal = each.value

  data_location {
    arn = aws_s3_bucket.buckets["silver"].arn
  }

  permissions = ["DATA_LOCATION_ACCESS"]

  depends_on = [aws_lakeformation_resource.silver]
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
# Gle Crawler LF grants: allows each crawler role to register S3 locations and
# create/update tables in its target Glue database (raw_db)
# ---------------------------------------------------------------------------
resource "aws_lakeformation_permissions" "glue_crawlers_location" {
  for_each = var.create ? var.glue_crawlers : {}

  principal = aws_iam_role.glue_crawlers[each.key].arn

  data_location {
    arn = aws_s3_bucket.buckets[each.value.s3_bucket_key].arn
  }

  permissions = ["DATA_LOCATION_ACCESS"]

  depends_on = [
    aws_lakeformation_resource.raw,
    aws_lakeformation_resource.bronze,
    aws_lakeformation_resource.silver,
  ]
}

resource "aws_lakeformation_permissions" "glue_crawlers_database" {
  for_each = var.create ? var.glue_crawlers : {}

  principal = aws_iam_role.glue_crawlers[each.key].arn

  database {
    name = aws_glue_catalog_database.databases[each.value.database_key].name
  }

  permissions                   = ["CREATE_TABLE", "ALTER", "DESCRIBE"]
  permissions_with_grant_option = []

  depends_on = [aws_lakeformation_data_lake_settings.this]
}

# ---------------------------------------------------------------------------
# Data Engineer LF grants: DESCRIBE on databases, SELECT/DESCRIBE (+ DROP in
# dev) on all tables in bronze and silver.
# Table-level permissions are driven by lakeformation_de_table_permissions so
# dev can include DROP without touching prod/stg tfvars.
# ---------------------------------------------------------------------------
resource "aws_lakeformation_permissions" "de_bronze_database" {
  for_each = var.create ? toset(var.lakeformation_de_role_arns) : toset([])

  principal = each.value

  database {
    name = aws_glue_catalog_database.databases["bronze"].name
  }

  permissions                   = var.lakeformation_de_database_permissions
  permissions_with_grant_option = []

  depends_on = [aws_lakeformation_data_lake_settings.this]
}

resource "aws_lakeformation_permissions" "de_silver_database" {
  for_each = var.create ? toset(var.lakeformation_de_role_arns) : toset([])

  principal = each.value

  database {
    name = aws_glue_catalog_database.databases["silver"].name
  }

  permissions                   = var.lakeformation_de_database_permissions
  permissions_with_grant_option = []

  depends_on = [aws_lakeformation_data_lake_settings.this]
}

resource "aws_lakeformation_permissions" "de_bronze_tables" {
  for_each = var.create ? toset(var.lakeformation_de_role_arns) : toset([])

  principal = each.value

  table {
    database_name = aws_glue_catalog_database.databases["bronze"].name
    wildcard      = true
  }

  permissions                   = var.lakeformation_de_table_permissions
  permissions_with_grant_option = []

  depends_on = [aws_lakeformation_data_lake_settings.this]
}

resource "aws_lakeformation_permissions" "de_silver_tables" {
  for_each = var.create ? toset(var.lakeformation_de_role_arns) : toset([])

  principal = each.value

  table {
    database_name = aws_glue_catalog_database.databases["silver"].name
    wildcard      = true
  }

  permissions                   = var.lakeformation_de_table_permissions
  permissions_with_grant_option = []

  depends_on = [aws_lakeformation_data_lake_settings.this]
}

resource "aws_lakeformation_permissions" "de_raw_database" {
  for_each = var.create ? toset(var.lakeformation_de_role_arns) : toset([])

  principal = each.value

  database {
    name = aws_glue_catalog_database.databases["raw"].name
  }

  permissions                   = var.lakeformation_de_database_permissions
  permissions_with_grant_option = []

  depends_on = [aws_lakeformation_data_lake_settings.this]
}

resource "aws_lakeformation_permissions" "de_raw_tables" {
  for_each = var.create ? toset(var.lakeformation_de_role_arns) : toset([])

  principal = each.value

  table {
    database_name = aws_glue_catalog_database.databases["raw"].name
    wildcard      = true
  }

  permissions                   = var.lakeformation_de_table_permissions
  permissions_with_grant_option = []

  depends_on = [aws_lakeformation_data_lake_settings.this]
}

# ---------------------------------------------------------------------------
# dbt Core ECS task role LF grants
# The task role needs:
#   raw      → DATA_LOCATION_ACCESS + SELECT on all tables (Athena source reads)
#   bronze   → DATA_LOCATION_ACCESS + CREATE_TABLE on DB + full table access
#              (SELECT/INSERT/DELETE/ALTER) for Iceberg table management
# ---------------------------------------------------------------------------
resource "aws_lakeformation_permissions" "dbt_raw_location" {
  for_each = var.create ? toset(var.lakeformation_dbt_task_role_arns) : toset([])

  principal = each.value

  data_location {
    arn = aws_s3_bucket.buckets["raw"].arn
  }

  permissions = ["DATA_LOCATION_ACCESS"]

  depends_on = [aws_lakeformation_resource.raw]
}

resource "aws_lakeformation_permissions" "dbt_raw_database" {
  for_each = var.create ? toset(var.lakeformation_dbt_task_role_arns) : toset([])

  principal = each.value

  database {
    name = aws_glue_catalog_database.databases["raw"].name
  }

  permissions                   = ["DESCRIBE"]
  permissions_with_grant_option = []

  depends_on = [aws_lakeformation_data_lake_settings.this]
}

resource "aws_lakeformation_permissions" "dbt_raw_tables" {
  for_each = var.create ? toset(var.lakeformation_dbt_task_role_arns) : toset([])

  principal = each.value

  table {
    database_name = aws_glue_catalog_database.databases["raw"].name
    wildcard      = true
  }

  permissions                   = ["SELECT", "DESCRIBE"]
  permissions_with_grant_option = []

  depends_on = [aws_lakeformation_data_lake_settings.this]
}

resource "aws_lakeformation_permissions" "dbt_bronze_location" {
  for_each = var.create ? toset(var.lakeformation_dbt_task_role_arns) : toset([])

  principal = each.value

  data_location {
    arn = aws_s3_bucket.buckets["bronze"].arn
  }

  permissions = ["DATA_LOCATION_ACCESS"]

  depends_on = [aws_lakeformation_resource.bronze]
}

resource "aws_lakeformation_permissions" "dbt_bronze_database" {
  for_each = var.create ? toset(var.lakeformation_dbt_task_role_arns) : toset([])

  principal = each.value

  database {
    name = aws_glue_catalog_database.databases["bronze"].name
  }

  permissions                   = ["CREATE_TABLE", "DESCRIBE"]
  permissions_with_grant_option = []

  depends_on = [aws_lakeformation_data_lake_settings.this]
}

resource "aws_lakeformation_permissions" "dbt_bronze_tables" {
  for_each = var.create ? toset(var.lakeformation_dbt_task_role_arns) : toset([])

  principal = each.value

  table {
    database_name = aws_glue_catalog_database.databases["bronze"].name
    wildcard      = true
  }

  permissions                   = ["SELECT", "INSERT", "DELETE", "ALTER", "DESCRIBE"]
  permissions_with_grant_option = []

  depends_on = [aws_lakeformation_data_lake_settings.this]
}

# ---------------------------------------------------------------------------
# NOTE: lakeformation:GetDataAccess for SSO roles is managed via the security
# stack (terraform/security/locals.tf), not here. DataEngineer inline policies
# include lakeformation:Get* which covers GetDataAccess. Analyst and Auditor
# permission sets should be added there when their SSO permission sets are created.
# ---------------------------------------------------------------------------
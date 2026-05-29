# ---------------------------------------------------------------------------
# Glue Databases for layers (bronze / silver)
# ---------------------------------------------------------------------------
resource "aws_glue_catalog_database" "databases" {
  for_each = var.glue_databases

  name        = "${each.value.name}_${var.environment}"
  description = each.value.description
  # S3 paths for DB locations
  location_uri = can(regex("bronze", each.key)) ? "s3://escr20-bronze-${var.environment}/" : can(regex("silver", each.key)) ? "s3://escr20-silver-${var.environment}/" : "s3://escr20-landing-zone-raw-${var.environment}"


  tags = merge(var.tags, {
    Name        = "${each.value.name}-${var.environment}"
    Environment = var.environment
    Layer       = each.key
  })
}
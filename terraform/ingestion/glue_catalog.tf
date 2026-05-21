# ---------------------------------------------------------------------------
# Glue Databases for layers (bronze / silver)
# ---------------------------------------------------------------------------
resource "aws_glue_catalog_database" "databases" {
  for_each = var.glue_databases

  name         = "${each.value.name}_${var.environment}"
  description  = each.value.description
  location_uri = can(regex("bronze", each.key)) ? "s3://escr20-bronze-dev/" : "s3://escr20-silver-dev/"


  tags = merge(var.tags, {
    Name        = "${each.value.name}-${var.environment}"
    Environment = var.environment
    Layer       = each.key
  })
}
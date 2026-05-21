# ---------------------------------------------------------------------------
# Glue Databases for layers (bronze / silver)
# ---------------------------------------------------------------------------
resource "aws_glue_catalog_database" "databases" {
  for_each = var.glue_databases

  name        = "${each.value.name}_${var.environment}"
  description = each.value.description

  tags = merge(var.tags, {
    Name        = "${each.value.name}-${var.environment}"
    Environment = var.environment
    Layer       = each.key
  })
}
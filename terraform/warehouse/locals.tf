locals {
  name = "${var.company_name}-${var.environment}"
  athena_buckets = {
    athena_results = var.athena_results.name
  }
}
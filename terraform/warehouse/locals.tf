locals {
  name = "${var.company_name}-${var.environment}"
  athena_buckets = {
    athena_results = var.athena_results.name
  }
  dbt_cloud_ips = [
    "52.45.144.63",
    "54.81.134.249",
    "52.22.161.231",
    "52.3.77.232",
    "3.214.191.130",
    "34.233.79.135",
  ]
}

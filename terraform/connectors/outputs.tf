# Connectors Stack — Outputs

output "oracle_source_id" {
  description = "Airbyte source ID for the Oracle connector."
  value       = try(airbyte_source.oracle[0].source_id, null)
}

output "mssql_source_id" {
  description = "Airbyte source ID for the SQL Server connector."
  value       = try(airbyte_source.mssql[0].source_id, null)
}

output "s3_destination_id" {
  description = "Airbyte destination ID for the S3 Data Lake connector."
  value       = try(airbyte_destination.s3[0].destination_id, null)
}

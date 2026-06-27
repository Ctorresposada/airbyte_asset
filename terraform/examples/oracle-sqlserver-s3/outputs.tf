# Example outputs

output "oracle_source_id" {
  description = "Airbyte source ID for Oracle."
  value       = airbyte_source.oracle.source_id
}

output "mssql_source_id" {
  description = "Airbyte source ID for SQL Server."
  value       = airbyte_source.mssql.source_id
}

output "s3_destination_id" {
  description = "Airbyte destination ID for S3 Data Lake."
  value       = airbyte_destination.s3_data_lake.destination_id
}

output "oracle_connection_id" {
  description = "Airbyte connection ID for Oracle → S3."
  value       = airbyte_connection.oracle_to_s3.connection_id
}

output "mssql_connection_id" {
  description = "Airbyte connection ID for SQL Server → S3."
  value       = airbyte_connection.mssql_to_s3.connection_id
}

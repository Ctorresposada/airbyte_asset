#output "oracle_source_id" {
#  description = "Airbyte source ID for the Oracle source, or null when the stack is disabled (create = false)"
#  value       = try(airbyte_source.oracle[0].source_id, null)
#}
#
#output "mssql_source_id" {
#  description = "Airbyte source ID for the SQL Server source, or null when the stack is disabled (create = false)"
#  value       = try(airbyte_source.mssql[0].source_id, null)
#}
#
#output "google_drive_source_id" {
#  description = "Airbyte source ID for the Google Drive source, or null when the stack is disabled (create = false)"
#  value       = try(airbyte_source.google_drive[0].source_id, null)
#}
#
#output "docebo_source_id" {
#  description = "Airbyte source ID for the Docebo custom source, or null when the stack is disabled (create = false)"
#  value       = try(airbyte_source.docebo[0].source_id, null)
#}
#
#output "oracle_connection_id" {
#  description = "Airbyte connection ID for oracle to s3, or null when the stack is disabled (create = false)"
#  value       = try(airbyte_connection.oracle_to_s3[0].connection_id, null)
#}
#
#output "mssql_connection_id" {
#  description = "Airbyte connection ID for mssql to s3, or null when the stack is disabled (create = false)"
#  value       = try(airbyte_connection.mssql_to_s3[0].connection_id, null)
#}
#
#output "google_drive_connection_id" {
#  description = "Airbyte connection ID for google-drive to s3, or null when the stack is disabled (create = false)"
#  value       = try(airbyte_connection.google_drive_to_s3[0].connection_id, null)
#}
#
#output "docebo_connection_id" {
#  description = "Airbyte connection ID for docebo to s3, or null when the stack is disabled (create = false)"
#  value       = try(airbyte_connection.docebo_to_s3[0].connection_id, null)
#}

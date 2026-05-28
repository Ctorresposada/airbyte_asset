locals {
  # Decoded secret payloads. The try() fallback to an empty object keeps
  # `terraform plan` working when the stack is disabled (var.create = false)
  # and the data sources are not materialized.
  s3_creds = try(jsondecode(data.aws_secretsmanager_secret_version.s3_credentials[0].secret_string), {})
  #  oracle_creds       = try(jsondecode(data.aws_secretsmanager_secret_version.oracle[0].secret_string), {})
  #  mssql_creds        = try(jsondecode(data.aws_secretsmanager_secret_version.mssql[0].secret_string), {})
  #  google_drive_creds = try(jsondecode(data.aws_secretsmanager_secret_version.google_drive[0].secret_string), {})
  #  docebo_creds       = try(jsondecode(data.aws_secretsmanager_secret_version.docebo[0].secret_string), {})
  #
  # Known Airbyte connector definition IDs for built-in connectors.
  # Stable across self-hosted instances since they are baked into the OSS catalog.
  #tflint-ignore: terraform_unused_declarations
  oracle_definition_id = "b39a7370-74c3-45a6-ac3a-380d48520a83"
  #tflint-ignore: terraform_unused_declarations
  mssql_definition_id = "b5ea17b1-f170-46dc-bc6d-6b0cd0a983d3"
  #tflint-ignore: terraform_unused_declarations
  google_drive_definition_id = "9f8dda77-1048-4368-815b-269bf54ee9b8"
  #tflint-ignore: terraform_unused_declarations
  s3_destination_definition_id = "4816b78f-1489-44c1-9060-4b19d5fa9363"
}

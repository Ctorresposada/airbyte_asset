output "data_lake_caylent_group_id" {
  description = "Group ID of the Data-Lake-Caylent Identity Store group, or null when the stack is disabled (create = false)."
  value       = try(aws_identitystore_group.data_lake_caylent[0].group_id, null)
}

output "data_lake_caylent_group_arn" {
  description = "ARN of the Data-Lake-Caylent Identity Store group, or null when the stack is disabled (create = false)."
  value       = try(aws_identitystore_group.data_lake_caylent[0].arn, null)
}

output "data_engineer_prod_permission_set_arn" {
  description = "ARN of the DataEngineer_Prod permission set, or null when the stack is disabled (create = false)."
  value       = try(aws_ssoadmin_permission_set.data_engineer_prod[0].arn, null)
}

output "data_engineer_dev_permission_set_arn" {
  description = "ARN of the DataEngineer_Dev permission set, or null when the stack is disabled (create = false)."
  value       = try(aws_ssoadmin_permission_set.data_engineer_dev[0].arn, null)
}

output "account_assignments" {
  description = "Map of account-assignment keys to their target account IDs and permission set ARNs. Empty when the stack is disabled (create = false)."
  value = {
    for k, v in aws_ssoadmin_account_assignment.this :
    k => {
      target_account_id  = v.target_id
      permission_set_arn = v.permission_set_arn
      principal_id       = v.principal_id
    }
  }
}

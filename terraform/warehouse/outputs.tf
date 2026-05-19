output "redshift_kms_key_arn" {
  description = "ARN of the KMS CMK used to encrypt Redshift data at rest, or null when the stack is disabled (create = false)."
  value       = try(module.redshift_kms[0].key_arn, null)
}

output "redshift_kms_key_id" {
  description = "Globally unique identifier of the Redshift KMS CMK, or null when the stack is disabled (create = false)."
  value       = try(module.redshift_kms[0].key_id, null)
}

output "redshift_kms_alias_arn" {
  description = "ARN of the KMS alias for the Redshift CMK, or null when the stack is disabled (create = false)."
  value       = try(module.redshift_kms[0].aliases["alias/${local.name}-redshift"].arn, null)
}

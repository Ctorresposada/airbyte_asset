output "flow_log_bucket_arn" {
  description = "ARN of the centralized S3 bucket receiving VPC Flow Logs from all source accounts. Used as the flow_log_bucket_arn input to the networking stack, or null when the stack is disabled (create = false)."
  value       = try(module.flow_log_bucket[0].s3_bucket_arn, null)
}

output "flow_log_bucket_id" {
  description = "Name (ID) of the centralized VPC Flow Logs S3 bucket, or null when the stack is disabled (create = false)."
  value       = try(module.flow_log_bucket[0].s3_bucket_id, null)
}

output "flow_log_kms_key_arn" {
  description = "ARN of the KMS CMK used to encrypt VPC Flow Logs in the centralized bucket, or null when the stack is disabled (create = false)."
  value       = try(module.flow_log_kms[0].key_arn, null)
}

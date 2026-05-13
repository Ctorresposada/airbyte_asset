output "flow_log_bucket_arn" {
  description = "ARN of the centralized S3 bucket receiving VPC Flow Logs from all source accounts. Used as the flow_log_bucket_arn input to the networking stack."
  value       = module.flow_log_bucket.s3_bucket_arn
}

output "flow_log_bucket_id" {
  description = "Name (ID) of the centralized VPC Flow Logs S3 bucket."
  value       = module.flow_log_bucket.s3_bucket_id
}

output "flow_log_kms_key_arn" {
  description = "ARN of the KMS CMK used to encrypt VPC Flow Logs in the centralized bucket."
  value       = module.flow_log_kms.key_arn
}

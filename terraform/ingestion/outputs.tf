output "aws_caller_identity" {
  description = "AWS caller identity information, or null when the stack is disabled (create = false)"
  value       = try(data.aws_caller_identity.this[0], null)
}

output "bucket_names" {
  value = {
    for k, v in aws_s3_bucket.buckets : k => v.id
  }
  description = "All S3 bucket names"
}

output "bucket_arns" {
  value = {
    for k, v in aws_s3_bucket.buckets : k => v.arn
  }
  description = "All S3 bucket ARNs"
}
output "aws_caller_identity" {
  description = "AWS caller identity information, or null when the stack is disabled (create = false)"
  value       = try(data.aws_caller_identity.this[0], null)
}

output "bucket_name" {
  value       = aws_s3_bucket.raw.id
  description = "S3 raw bucket name"
}

output "bucket_arn" {
  value       = aws_s3_bucket.raw.arn
  description = "S3 raw bucket ARN"
}
output "aws_caller_identity" {
  description = "AWS caller identity information, or null when the stack is disabled (create = false)"
  value       = try(data.aws_caller_identity.this[0], null)
}

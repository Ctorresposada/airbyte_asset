output "backend_config_terraform_block" {
  description = "Terraform backend configuration block"
  value       = <<EOT

# Now that you have created your terraform state management resources perform the following:
# 1. Copy and paste the code block below into your aft-main/terraform/backend.tf file
# 2. Run 'terraform init -migrate-state' to move the state to the new S3 backend
#
# In the even that you wish to remove AFT completely or migrate to a different state management solution:
# 1. Backup the state file locally by running: 'aws s3 cp s3://aftv2-terraform-state/aws/aft-management.tfstate ./backup-terraform.tfstate'
# 2. Then remove your terraform backend block and run: 'terraform init -migrate-state'


terraform {
  backend "s3" {
    bucket       = "${module.s3_bucket.s3_bucket_id}"
    key          = "aws/aft-management.tfstate"
    region       = "${data.aws_region.current.region}"
    use_lockfile = true
    encrypt      = true
    kms_key_id   = "${module.kms_key.key_arn}"
  }
}
EOT
}

output "s3_bucket_id" {
  description = "The ID of the S3 bucket"
  value       = module.s3_bucket.s3_bucket_id
}

output "kms_key_arn" {
  description = "The ARN of the KMS key"
  value       = module.kms_key.key_arn
}

output "state_management_iam_policy_arn" {
  description = "The ARN of the State Management IAM policy"
  value       = var.create_state_management_iam_policy ? aws_iam_policy.state_management[0].arn : null
}

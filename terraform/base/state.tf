# When the time to destroy the infrastructure comes, comment out the backend configuration
# block below and run `terraform init -migrate-state` to move it locally.

# terraform {
#   backend "s3" {
#     bucket       = "terraform-caylent-aws-terraform-state"
#     key          = "terraform.tfstate"
#     region       = "us-east-1"
#     use_lockfile = true
#     encrypt      = true
#     kms_key_id   = "arn:aws:kms:us-east-1:494531450480:key/3b74d641-a7c4-49d4-b656-ec4a23d96245"
#   }
# }

module "terraform_state_management" {
  source = "../modules/state-management"

  s3_bucket_name = "${var.company_name}-tf-state"
  kms_key_alias  = "${var.company_name}-tf-state"
}

create       = true
environment  = "dev"
aws_region   = "us-east-1"
team         = "devops"
company_name = "region-20"
account_id   = "784590287037"

# ECR repository now lives in the service-account stack. These are populated from
# the service-account stack's ecr_repository_url / ecr_repository_arn outputs
# after its first apply. Until then the transformations plan/apply will fail the
# non-empty validation, which is intentional - apply service-account first.
ecr_repository_url = "PLACEHOLDER_REPLACE_AFTER_SERVICE_ACCOUNT_APPLY"
ecr_repository_arn = "PLACEHOLDER_REPLACE_AFTER_SERVICE_ACCOUNT_APPLY"

dbt_task_cpu           = 1024
dbt_task_memory        = 2048
dbt_log_retention_days = 30

# IAM principals allowed to use the transformations CMK directly (e.g. SSO roles
# that inspect dbt artifacts or read the secret from the console).
kms_key_users = [
  "arn:aws:iam::784590287037:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_DataEngineer_Dev_cd1bbeb9335fcaa8",
  "arn:aws:iam::784590287037:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AWSAdministratorAccess_9a7f3e7b3aa4c5bb",
]

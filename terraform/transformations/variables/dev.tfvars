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
ecr_repository_url = "471624149663.dkr.ecr.us-east-1.amazonaws.com/region-20-shared-dbt-core"
ecr_repository_arn = "arn:aws:ecr:us-east-1:471624149663:repository/region-20-shared-dbt-core"

enable_dbt_task = true # Whether to enable the DBT task resource, needs the CI pipeline and SSM parameter created first

dbt_task_cpu           = 1024
dbt_task_memory        = 2048
dbt_log_retention_days = 30

# IAM principals allowed to use the transformations CMK directly (e.g. SSO roles
# that inspect dbt artifacts or read the secret from the console).
kms_key_users = [
  "arn:aws:iam::784590287037:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_DataEngineer_Dev_cd1bbeb9335fcaa8",
  "arn:aws:iam::784590287037:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AWSAdministratorAccess_9a7f3e7b3aa4c5bb",
]

redshift_db     = "gold"
redshift_schema = "gold"
redshift_user   = "dbt_service"

# SSM parameter created by Terraform and written by CI after every successful dbt Core ECR push.
dbt_image_ssm_parameter_name = "/region-20/dev/dbt-core/image-uri"

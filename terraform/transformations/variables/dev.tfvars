create       = true           # Master toggle; false soft-deletes all resources while keeping state, ex true
environment  = "dev"          # Deployment environment; drives resource names, TF workspace, and SSM path suffix, ex "dev"
aws_region   = "us-east-1"    # Target AWS region; changing it relocates all resources, ex "us-east-1"
team         = "devops"       # Owning team tag applied to all resources, ex "devops"
company_name = "region-20"    # Resource name prefix for ECS cluster, task, and KMS key, ex "region-20"
account_id   = "784590287037" # Target AWS account ID (dev); used in cross-account role ARN construction, ex "784590287037"

# ECR repository now lives in the service-account stack. These are populated from
# the service-account stack's ecr_repository_url / ecr_repository_arn outputs
# after its first apply. Until then the transformations plan/apply will fail the
# non-empty validation, which is intentional - apply service-account first.
ecr_repository_url = "471624149663.dkr.ecr.us-east-1.amazonaws.com/region-20-shared-dbt-core"  # Full ECR image URL for the shared dbt Core image (from service-account stack output), ex "471624149663.dkr.ecr.us-east-1.amazonaws.com/region-20-shared-dbt-core"
ecr_repository_arn = "arn:aws:ecr:us-east-1:471624149663:repository/region-20-shared-dbt-core" # ECR repository ARN for IAM policy scoping on the ECS exec role, ex "arn:aws:ecr:us-east-1:471624149663:repository/region-20-shared-dbt-core"

enable_dbt_task = true # Whether to enable the DBT task resource, needs the CI pipeline and SSM parameter created first

dbt_task_cpu           = 1024 # Fargate vCPU units for the dbt ECS task; 1024 = 1 vCPU, ex 1024, allowed values: 256, 512, 1024, 2048, 4096
dbt_task_memory        = 2048 # Fargate task memory MiB; must be a valid CPU-memory combination per AWS docs, ex 2048, allowed values (for 1024 CPU): 2048, 3072, 4096, 5120, 6144, 7168, 8192
dbt_log_retention_days = 30   # Days CloudWatch retains dbt task and cluster logs; higher increases storage cost, ex 30

# IAM principals allowed to use the transformations CMK directly (e.g. SSO roles
# that inspect dbt artifacts or read the secret from the console).
kms_key_users = [
  "arn:aws:iam::784590287037:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_DataEngineer_Dev_cd1bbeb9335fcaa8",
  "arn:aws:iam::784590287037:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AWSAdministratorAccess_9a7f3e7b3aa4c5bb",
]

redshift_db     = "gold"        # Redshift database dbt connects to; must match warehouse stack's redshift_db_name, ex "gold"
redshift_schema = "gold"        # dbt target schema within Redshift; dbt_service user has full CREATE/DROP rights on this schema, ex "gold"
redshift_user   = "dbt_service" # Redshift IAM-brokered user dbt authenticates as; must match warehouse stack's dbt_redshift_user, ex "dbt_service"

# SSM parameter created by Terraform and written by CI after every successful dbt Core ECR push.
dbt_image_ssm_parameter_name = "/region-20/dev/dbt-core/image-uri" # SSM path storing the live dbt image URI; CI overwrites this after each successful ECR push, ex "/region-20/dev/dbt-core/image-uri"

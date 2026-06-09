create       = true           # Provision resources; false soft-deletes while keeping state
environment  = "prod"         # Deployment env; drives names, workspace, and bucket/SSM-path suffixes
aws_region   = "us-east-1"    # Target region; changing it relocates all resources
team         = "devops"       # Owning team tag
company_name = "region-20"    # Name prefix for resources
account_id   = "029750300494" # Target AWS account; builds the cross-account assume-role ARN and ARN conditions

# Shared dbt Core ECR repo in the service account (471624149663); same across all envs.
ecr_repository_url = "471624149663.dkr.ecr.us-east-1.amazonaws.com/region-20-shared-dbt-core"  # image source for the initial task def
ecr_repository_arn = "arn:aws:ecr:us-east-1:471624149663:repository/region-20-shared-dbt-core" # scopes the exec role's ECR pull

enable_dbt_task        = false # Whether to enable the DBT task resource, needs the CI pipeline and SSM parameter created first
dbt_task_cpu           = 2048  # Fargate vCPU units (2048 = 2 vCPU); raise for heavier dbt runs, must pair with valid memory
dbt_task_memory        = 4096  # Fargate task memory MiB; must be compatible with the chosen CPU
dbt_log_retention_days = 30    # Days CloudWatch keeps dbt task/cluster logs; higher = more storage cost

kms_key_users = [] # IAM principals allowed to use the transformations CMK; empty for first apply (prod SSO ARNs unknown)

redshift_db     = "gold"        # Redshift database dbt connects to; must match warehouse stack
redshift_schema = "gold"        # dbt target schema; dbt_service has full rights on gold
redshift_user   = "dbt_service" # Redshift user dbt authenticates as; must match warehouse stack

dbt_image_ssm_parameter_name = "/region-20/prod/dbt-core/image-uri" # SSM path holding the live dbt image URI; CI overwrites after each push

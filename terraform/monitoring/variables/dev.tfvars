create                    = true           # Master toggle; false soft-deletes all resources while keeping state, ex true
environment               = "dev"          # Deployment environment; drives resource names and cross-stack data lookups, ex "dev"
aws_region                = "us-east-1"    # Target AWS region; changing it relocates all resources, ex "us-east-1"
team                      = "devops"       # Owning team tag applied to all resources, ex "devops"
company_name              = "region-20"    # Resource name prefix used for dashboards and alarms, ex "region-20"
account_id                = "784590287037" # Target AWS account ID (dev); used for cross-account role ARN construction, ex "784590287037"
enable_airbyte_monitoring = true           # Create CloudWatch alarms and dashboard panels for the Airbyte EC2/RDS; false skips them entirely, ex true
enable_dbt_ecs_monitoring = true           # Create CloudWatch alarms and dashboard panels for the dbt Core ECS cluster; false skips them entirely, ex true

# SNS subscribers for warning-severity alerts; each address receives a confirmation email on first apply, ex ["oncall@example.com"]
warning_emails = [
  "matias.kahnlein@caylent.com",
  "isadora.almeida@caylent.com",
  "cristopher.torres@caylent.com",
  "cassio.vargas@caylent.com",
]

# SNS subscribers for critical-severity alerts; each address receives a confirmation email on first apply, ex ["oncall@example.com"]
critical_emails = [
  "matias.kahnlein@caylent.com",
  "isadora.almeida@caylent.com",
  "cristopher.torres@caylent.com",
  "cassio.vargas@caylent.com",
]

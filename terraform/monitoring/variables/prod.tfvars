create                    = true                          # Provision this stack's resources; false soft-deletes them while keeping state/code
environment               = "prod"                        # Deployment env; drives resource names, TF workspace, and cross-stack data lookups
aws_region                = "us-east-1"                   # Target region; changing it relocates every resource
team                      = "devops"                      # Owning team; applied as a tag only
company_name              = "region-20"                   # Name prefix for resources
account_id                = "029750300494"                # Target AWS account; builds the cross-account assume-role ARN
enable_airbyte_monitoring = true                          # Create CloudWatch alarms + dashboard panels for the Airbyte EC2/RDS; false skips them
enable_dbt_ecs_monitoring = true                          # Create CloudWatch alarms + dashboard panels for the dbt Core ECS cluster; false skips them
warning_emails            = ["datalake-alerts@esc20.net"] # Subscribers to the Warning SNS topic; each address gets an SNS confirmation email
critical_emails           = ["datalake-alerts@esc20.net"] # Subscribers to the Critical SNS topic; each address gets an SNS confirmation email

redshift_compute_seconds_threshold = 7200 # Hourly ComputeSeconds sum that fires the Redshift compute-usage alarm; raise if prod load makes it noisy

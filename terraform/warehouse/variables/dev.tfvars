create             = true
environment        = "dev"
aws_region         = "us-east-1"
team               = "devops"
company_name       = "region-20"
account_id         = "784590287037"
redshift_key_users = ["arn:aws:iam::784590287037:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_DataEngineer_Dev_cd1bbeb9335fcaa8", "arn:aws:iam::784590287037:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AWSAdministratorAccess_9a7f3e7b3aa4c5bb"]

data_lake_bucket_arns       = ["arn:aws:s3:::escr20-bronce-dev", "arn:aws:s3:::escr20-silver-dev"]
redshift_max_capacity       = 32
redshift_log_retention_days = 30

#Athena configurations
athena_results = {
  name               = "query-athena-results-dev"
  layer              = "athena"
  transition_ia      = 7
  transition_glacier = 30
  expiration_days    = 90
}
environment = "shared"       # Environment label for this security/delegated-admin account, ex "shared"
aws_region  = "us-east-1"    # Target region; must match where IAM Identity Center is configured, ex "us-east-1"
team        = "devops"       # Owning team tag applied to all resources, ex "devops"
account_id  = "510473518105" # Security account ID configured as IDC delegated administrator, ex "510473518105"

# IAM Identity Center instance hosted in the management account (992382717104).
# This stack manages IDC resources from the security account via delegated
# administrator privileges.
instance_arn      = "arn:aws:sso:::instance/ssoins-72230b5bed124295" # IAM Identity Center instance ARN from the management account, ex "arn:aws:sso:::instance/ssoins-..."
identity_store_id = "d-9067ea424b"                                   # IDC identity store ID used to look up groups and users, ex "d-9067ea424b"

# IDC group whose members receive DataEngineer permission set assignments; group_id from Identity Center console
data_lake_group = {
  group_id     = "a4e8f428-e0a1-7016-009c-351d5452cc60"
  display_name = "Data-Lake-Caylent"
  description  = "Group for Caylent Members working with Data Lake for ESC Region 20"
}

# Read-only permission set for prod DataEngineer; session_duration in ISO 8601 (PT8H = 8 hours), managed_policies are all *ReadOnly or viewer-level
data_engineer_prod_permission_set = {
  name             = "DataEngineer_Prod"
  description      = "Production environment DataEngineer permissions"
  session_duration = "PT8H"
  managed_policies = [
    "arn:aws:iam::aws:policy/AWSGlueConsoleFullAccess",
    "arn:aws:iam::aws:policy/AWSLakeFormationDataAdmin",
    "arn:aws:iam::aws:policy/AWSSecretsManagerClientReadOnlyAccess",
    "arn:aws:iam::aws:policy/AmazonAthenaFullAccess",
    "arn:aws:iam::aws:policy/AmazonEventBridgeReadOnlyAccess",
    "arn:aws:iam::aws:policy/AmazonRedshiftReadOnlyAccess",
    "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess",
    "arn:aws:iam::aws:policy/AmazonSNSReadOnlyAccess",
    "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess",
  ]
}

# Broader write-access permission set for dev DataEngineer; includes Lambda, EC2 full access, and S3/Secrets write for development
data_engineer_dev_permission_set = {
  name             = "DataEngineer_Dev"
  description      = "Development environment DataEngineer permissions"
  session_duration = "PT8H"
  managed_policies = [
    "arn:aws:iam::aws:policy/AWSGlueConsoleFullAccess",
    "arn:aws:iam::aws:policy/AWSLambda_FullAccess",
    "arn:aws:iam::aws:policy/AWSStepFunctionsFullAccess",
    "arn:aws:iam::aws:policy/AmazonEC2FullAccess",
    "arn:aws:iam::aws:policy/AmazonEventBridgeFullAccess",
    "arn:aws:iam::aws:policy/AmazonRedshiftFullAccess",
    "arn:aws:iam::aws:policy/AmazonS3FullAccess",
    "arn:aws:iam::aws:policy/AmazonSNSFullAccess",
    "arn:aws:iam::aws:policy/CloudWatchFullAccessV2",
    "arn:aws:iam::aws:policy/SecretsManagerReadWrite",
  ]
}

# Maps each permission set to its target AWS account; key is used as the TF workspace label
data_engineer_account_assignments = {
  "prod" = {
    aws_account_id = "029750300494"
  }
  "dev" = {
    aws_account_id = "784590287037"
  }
}

variable "create" {
  description = "Whether this stack should provision its resources. Set to false to soft-delete everything the stack manages while preserving state and code."
  type        = bool
  default     = true
}

variable "environment" {
  description = "Target deployment environment"
  type        = string
}

variable "aws_region" {
  description = "Target deployment region"
  type        = string
}

variable "team" {
  description = "Team that manages this project"
  type        = string
}

variable "company_name" {
  description = "Name to be appended to all resources as prefix"
  type        = string
}

variable "account_id" {
  description = "AWS account ID of the target account; used to construct the cross-account assume_role ARN"
  type        = string
}

variable "redshift_key_users" {
  description = "List of IAM principal ARNs (roles / users) permitted to use the Redshift KMS CMK for read/write operations (Encrypt, Decrypt, ReEncrypt*, GenerateDataKey*, DescribeKey). An empty list means no principals other than the account root can use the key — safe default for first apply."
  type        = list(string)
  default     = []
}

variable "redshift_db_name" {
  description = "Initial database name created inside the Redshift Serverless namespace. Per R2EP2IC-31, Redshift hosts the GOLD layer only."
  type        = string
  default     = "gold"
}

variable "redshift_admin_username" {
  description = "Username for the Redshift admin user. The password is managed by Redshift in Secrets Manager (manage_admin_password = true), so no password is set in Terraform."
  type        = string
  default     = "admin"
}

variable "dbt_redshift_user" {
  description = "Redshift database user that dbt Core authenticates as via IAM-brokered credentials. Created with PASSWORD DISABLE so it is reachable only through redshift-serverless:GetCredentials (no static password). Granted USAGE+CREATE+ALL on the gold schema and USAGE+SELECT on the bronze/silver Spectrum schemas."
  type        = string
  default     = "dbt_service"
}

variable "redshift_base_capacity" {
  description = "Base RPU capacity for the workgroup. Minimum allowed by Redshift Serverless is 8."
  type        = number
  default     = 8

  validation {
    condition     = var.redshift_base_capacity >= 8
    error_message = "redshift_base_capacity must be at least 8 RPUs."
  }
}

variable "redshift_max_capacity" {
  description = "Maximum RPU capacity the workgroup can scale to. Acts as a cost ceiling; set lower in dev environments."
  type        = number
  default     = 128

  validation {
    condition     = var.redshift_max_capacity >= var.redshift_base_capacity
    error_message = "redshift_max_capacity must be >= redshift_base_capacity."
  }
}

variable "redshift_log_retention_days" {
  description = "Retention in days for the CloudWatch log groups receiving Redshift Serverless userlog / connectionlog / useractivitylog exports. CloudWatch storage cost grows linearly with this value; dev should keep it short."
  type        = number
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 2192, 2557, 2922, 3288, 3653], var.redshift_log_retention_days)
    error_message = "redshift_log_retention_days must be one of the values CloudWatch Logs accepts: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 2192, 2557, 2922, 3288, 3653."
  }
}

variable "data_lake_bucket_arns" {
  description = "List of S3 bucket ARNs the Redshift cluster IAM role can read via Spectrum or COPY (e.g. the gold layer bucket). Empty list means no S3 read policy is attached. Pass full ARNs like \"arn:aws:s3:::escr20-gold-dev\"; the cluster gets s3:GetObject on <bucket-arn>/* and s3:ListBucket on <bucket-arn>."
  type        = list(string)
  default     = []
}

variable "vpn_enabled" {
  description = "Whether the Client VPN endpoint is deployed in this environment. When true, a data source looks up the client-vpn security group and an ingress rule is added to the Redshift SG on port 5439. Set to false when the VPN endpoint is not present (e.g. prod until the VPN is activated)."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "athena_results" {
  description = "Configuration for the Athena query results S3 bucket. name sets the bucket name; layer is a tag value; transition_ia/transition_glacier are days before moving objects to STANDARD_IA/GLACIER; expiration_days is when objects are permanently deleted."
  type = object({
    name               = string
    layer              = string
    transition_ia      = number
    transition_glacier = number
    expiration_days    = number
  })

  validation {
    condition     = var.athena_results.transition_ia >= 30
    error_message = "transition_ia must be >= 30 days (S3 STANDARD_IA minimum)."
  }

  validation {
    condition     = var.athena_results.transition_glacier > var.athena_results.transition_ia
    error_message = "transition_glacier must be greater than transition_ia."
  }

  validation {
    condition     = var.athena_results.expiration_days > var.athena_results.transition_glacier
    error_message = "expiration_days must be greater than transition_glacier."
  }
}

variable "bastion_instance_type" {
  description = "EC2 instance type for the SSH bastion host. t3.micro is sufficient for SSH tunneling workloads."
  type        = string
  default     = "t3.micro"
}

variable "glue_bronze_db_name" {
  description = "Glue Catalog database name for the bronze layer. Used to create the Spectrum external schema in Redshift Serverless. Must match the name provisioned by the ingestion stack."
  type        = string
}

variable "glue_silver_db_name" {
  description = "Glue Catalog database name for the silver layer. Used to create the Spectrum external schema in Redshift Serverless. Must match the name provisioned by the ingestion stack."
  type        = string
}

variable "bastion_log_retention_days" {
  description = "Retention in days for bastion CloudWatch log groups (auth logs). Must be one of the values accepted by CloudWatch Logs."
  type        = number
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 2192, 2557, 2922, 3288, 3653], var.bastion_log_retention_days)
    error_message = "bastion_log_retention_days must be one of the values CloudWatch Logs accepts: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 2192, 2557, 2922, 3288, 3653."
  }
}

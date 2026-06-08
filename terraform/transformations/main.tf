# Stack: transformations
# Runs dbt Core on AWS Fargate against the Redshift Serverless GOLD layer.
# Provisions: ECR repo for the dbt image, ECS Fargate cluster + task definition,
# task/execution IAM roles, an S3 artifacts bucket, a dedicated dbt service-account
# secret, CloudWatch logs, and a dedicated KMS CMK for the stack.

# Bootstrap parameter; CI overwrites value after every successful ECR push.
resource "aws_ssm_parameter" "dbt_image_uri" {
  #checkov:skip=CKV2_AWS_34: AWS SSM Parameter should be Encrypted
  count = var.create ? 1 : 0

  name  = var.dbt_image_ssm_parameter_name
  type  = "String"
  value = "${var.ecr_repository_url}:initial"

  description = "Currently deployed dbt Core image URI for the ${var.environment} environment. Written by CI after every successful ECR push; managed by Terraform on creation only."

  tags = merge(var.tags, {
    Name = "${local.name}-dbt-image-uri"
  })

  lifecycle {
    ignore_changes = [value]
  }
}

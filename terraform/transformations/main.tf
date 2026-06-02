# Stack: transformations
# Runs dbt Core on AWS Fargate against the Redshift Serverless GOLD layer.
# Provisions: ECR repo for the dbt image, ECS Fargate cluster + task definition,
# task/execution IAM roles, an S3 artifacts bucket, a dedicated dbt service-account
# secret, CloudWatch logs, and a dedicated KMS CMK for the stack.

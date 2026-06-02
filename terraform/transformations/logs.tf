# CloudWatch log group for the dbt Core ECS task containers (awslogs driver).
resource "aws_cloudwatch_log_group" "dbt_core" {
  #checkov:skip=CKV_AWS_338: Retention is environment-driven via var.dbt_log_retention_days. Dev keeps 30 days to control CloudWatch storage cost; prod sets >= 365.
  count = var.create ? 1 : 0

  name              = "/aws/ecs/${local.name}-dbt-core"
  retention_in_days = var.dbt_log_retention_days
  kms_key_id        = module.transformations_kms[0].key_arn
}

# CloudWatch log group for ECS cluster-level Container Insights / exec logging.
# Named under the dbt-core prefix so the stack CMK encryption-context condition
# covers it with a single ArnLike statement.
resource "aws_cloudwatch_log_group" "cluster" {
  #checkov:skip=CKV_AWS_338: Retention is environment-driven via var.dbt_log_retention_days. Dev keeps 30 days to control CloudWatch storage cost; prod sets >= 365.
  count = var.create ? 1 : 0

  name              = "/aws/ecs/${local.name}-dbt-core/cluster"
  retention_in_days = var.dbt_log_retention_days
  kms_key_id        = module.transformations_kms[0].key_arn
}

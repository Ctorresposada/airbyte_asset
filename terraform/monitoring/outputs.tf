# No cross-stack outputs are needed: monitoring resources (alarms, dashboards, SNS topics)
# are consumed directly in the AWS console and do not expose values required by other stacks.

output "warning_sns_topic_arn" {
  description = "ARN of the Warning SNS topic, or null when the stack is disabled."
  value       = try(aws_sns_topic.warning[0].arn, null)
}

output "critical_sns_topic_arn" {
  description = "ARN of the Critical SNS topic, or null when the stack is disabled."
  value       = try(aws_sns_topic.critical[0].arn, null)
}

output "sns_kms_key_arn" {
  description = "ARN of the KMS CMK used to encrypt both SNS topics, or null when the stack is disabled."
  value       = try(aws_kms_key.sns[0].arn, null)
}

output "data_platform_overview_dashboard_name" {
  description = "Name of the Data Platform Overview CloudWatch dashboard, or null when the stack is disabled."
  value       = try(aws_cloudwatch_dashboard.data_platform_overview[0].dashboard_name, null)
}

output "compute_and_jobs_dashboard_name" {
  description = "Name of the Compute and Jobs CloudWatch dashboard, or null when the stack is disabled."
  value       = try(aws_cloudwatch_dashboard.compute_and_jobs[0].dashboard_name, null)
}

output "pipeline_health_alarm_name" {
  description = "Name of the composite Pipeline Health CloudWatch alarm, or null when the stack is disabled."
  value       = try(aws_cloudwatch_composite_alarm.pipeline_health[0].alarm_name, null)
}

output "airbyte_webhook_url" {
  description = "Invoke URL for the Airbyte webhook endpoint. Configure this as the webhook URL in the Airbyte workspace notification settings."
  value       = try("https://${aws_api_gateway_rest_api.airbyte_webhook[0].id}.execute-api.${var.aws_region}.amazonaws.com/${aws_api_gateway_stage.airbyte_webhook[0].stage_name}/webhook", null)
}

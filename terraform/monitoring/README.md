# monitoring

CloudWatch dashboards, alarms, SNS notification topics, and log metric filters for the Region 20 data platform.

## Airbyte Notifications

Below are the available Airbyte notifications and their payload to be used as reference for lambda parsing

### Failed Sync

```
{
    "data": {
        "workspace": {
            "id":"b510e39b-e9e2-4833-9a3a-963e51d35fb4",
            "name":"Workspace1",
            "url":"https://link/to/ws"
        },
        "connection":{
            "id":"64d901a1-2520-4d91-93c8-9df438668ff0",
            "name":"Connection",
            "url":"https://link/to/connection"
        },
        "source":{
            "id":"c0655b08-1511-4e72-b7da-24c5d54de532",
            "name":"Source",
            "url":"https://link/to/source"
        },
        "destination":{
            "id":"5621c38f-8048-4abb-85ca-b34ff8d9a298",
            "name":"Destination",
            "url":"https://link/to/destination"
        },
        "jobId":9988,
        "startedAt":"2024-01-01T00:00:00Z",
        "finishedAt":"2024-01-01T01:00:00Z",
        "bytesEmitted":1000,
        "bytesCommitted":90,
        "recordsEmitted":89,
        "recordsCommitted":45,
        "errorMessage":"Something failed",
        "errorType": "config_error",
        "errorOrigin": "source",
        "bytesEmittedFormatted": "1000 B",
        "bytesCommittedFormatted":"90 B",
        "success":false,
        "durationInSeconds":3600,
        "durationFormatted":"1 hours 0 min"
    }
}
```

### Successful Sync

```
{
    "data": {
        "workspace": {
            "id":"b510e39b-e9e2-4833-9a3a-963e51d35fb4",
            "name":"Workspace1",
            "url":"https://link/to/ws"
        },
        "connection":{
            "id":"64d901a1-2520-4d91-93c8-9df438668ff0",
            "name":"Connection",
            "url":"https://link/to/connection"
        },
        "source":{
            "id":"c0655b08-1511-4e72-b7da-24c5d54de532",
            "name":"Source",
            "url":"https://link/to/source"
        },
        "destination":{
            "id":"5621c38f-8048-4abb-85ca-b34ff8d9a298",
            "name":"Destination",
            "url":"https://link/to/destination"
        },
        "jobId":9988,
        "startedAt":"2024-01-01T00:00:00Z",
        "finishedAt":"2024-01-01T01:00:00Z",
        "bytesEmitted":1000,
        "bytesCommitted":1000,
        "recordsEmitted":89,
        "recordsCommitted":89,
        "bytesEmittedFormatted": "1000 B",
        "bytesCommittedFormatted":"90 B",
        "success":true,
        "durationInSeconds":3600,
        "durationFormatted":"1 hours 0 min"
    }
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_archive"></a> [archive](#requirement\_archive) | ~> 2.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_archive"></a> [archive](#provider\_archive) | 2.8.0 |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.49.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_api_gateway_deployment.airbyte_webhook](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_deployment) | resource |
| [aws_api_gateway_integration.webhook_post](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_integration) | resource |
| [aws_api_gateway_method.webhook_post](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_method) | resource |
| [aws_api_gateway_resource.webhook](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_resource) | resource |
| [aws_api_gateway_rest_api.airbyte_webhook](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_rest_api) | resource |
| [aws_api_gateway_stage.airbyte_webhook](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_stage) | resource |
| [aws_cloudwatch_composite_alarm.pipeline_health](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_composite_alarm) | resource |
| [aws_cloudwatch_dashboard.compute_and_jobs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_dashboard) | resource |
| [aws_cloudwatch_dashboard.data_platform_overview](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_dashboard) | resource |
| [aws_cloudwatch_event_rule.dbt_task_failure](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_rule.glue_crawler_failure](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_target.dbt_task_failure_sns](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_event_target.glue_crawler_failure_sns](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_log_group.airbyte_webhook](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_metric_alarm.airbyte_cpu](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.airbyte_db_connections](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.airbyte_db_cpu](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.airbyte_db_read_latency](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.airbyte_db_storage](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.airbyte_db_write_latency](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.airbyte_disk](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.airbyte_memory](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.airbyte_status_check](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.athena_cost_control](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.athena_failed_queries](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.athena_slow_queries](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.dbt_ecs_cpu](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.dbt_ecs_memory](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.lambda_sync_duration](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.lambda_sync_error_rate](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.lambda_sync_errors](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.lambda_sync_throttling](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.redshift_active_queries](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.redshift_compute_usage](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.redshift_connection_limit](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.redshift_query_failures](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.s3_bronze_bucket_empty](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.s3_raw_bucket_empty](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.s3_silver_bucket_empty](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_iam_role.airbyte_webhook](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.airbyte_webhook](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.airbyte_webhook_basic_execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_kms_alias.sns](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.sns](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_lambda_function.airbyte_webhook](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_permission.apigateway_invoke](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_sns_topic.critical](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic) | resource |
| [aws_sns_topic.warning](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic) | resource |
| [aws_sns_topic_policy.critical_eventbridge](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_policy) | resource |
| [aws_sns_topic_policy.warning_webhook](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_policy) | resource |
| [aws_sns_topic_subscription.critical_email](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_subscription) | resource |
| [aws_sns_topic_subscription.warning_email](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_subscription) | resource |
| [archive_file.airbyte_webhook](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [aws_caller_identity.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_db_instance.airbyte](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/db_instance) | data source |
| [aws_ecs_cluster.dbt](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ecs_cluster) | data source |
| [aws_iam_policy_document.sns_kms_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_instance.airbyte](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/instance) | data source |
| [aws_vpc.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |
| [aws_vpc_endpoint.execute_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc_endpoint) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | AWS account ID of the target account; used to construct the cross-account assume\_role ARN | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | Target deployment region | `string` | n/a | yes |
| <a name="input_company_name"></a> [company\_name](#input\_company\_name) | Company name prefix used in resource names | `string` | n/a | yes |
| <a name="input_create"></a> [create](#input\_create) | Whether this stack should provision its resources. Set to false to soft-delete everything the stack manages while preserving state and code. | `bool` | `true` | no |
| <a name="input_critical_emails"></a> [critical\_emails](#input\_critical\_emails) | Email addresses subscribed to the Critical SNS topic. | `list(string)` | `[]` | no |
| <a name="input_enable_airbyte_monitoring"></a> [enable\_airbyte\_monitoring](#input\_enable\_airbyte\_monitoring) | Enable CloudWatch alarms and dashboard panels for the self-hosted Airbyte EC2 instance and RDS database. | `bool` | `false` | no |
| <a name="input_enable_dbt_ecs_monitoring"></a> [enable\_dbt\_ecs\_monitoring](#input\_enable\_dbt\_ecs\_monitoring) | Enable CloudWatch alarms and dashboard panels for the self-hosted dbt Core ECS Fargate cluster. | `bool` | `false` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Target deployment environment | `string` | n/a | yes |
| <a name="input_redshift_compute_seconds_threshold"></a> [redshift\_compute\_seconds\_threshold](#input\_redshift\_compute\_seconds\_threshold) | Hourly ComputeSeconds sum threshold for the Redshift compute usage alarm. | `number` | `7200` | no |
| <a name="input_team"></a> [team](#input\_team) | Team that manages this project | `string` | n/a | yes |
| <a name="input_warning_emails"></a> [warning\_emails](#input\_warning\_emails) | Email addresses subscribed to the Warning SNS topic. | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_airbyte_webhook_url"></a> [airbyte\_webhook\_url](#output\_airbyte\_webhook\_url) | Invoke URL for the Airbyte webhook endpoint. Configure this as the webhook URL in the Airbyte workspace notification settings. |
| <a name="output_compute_and_jobs_dashboard_name"></a> [compute\_and\_jobs\_dashboard\_name](#output\_compute\_and\_jobs\_dashboard\_name) | Name of the Compute and Jobs CloudWatch dashboard, or null when the stack is disabled. |
| <a name="output_critical_sns_topic_arn"></a> [critical\_sns\_topic\_arn](#output\_critical\_sns\_topic\_arn) | ARN of the Critical SNS topic, or null when the stack is disabled. |
| <a name="output_data_platform_overview_dashboard_name"></a> [data\_platform\_overview\_dashboard\_name](#output\_data\_platform\_overview\_dashboard\_name) | Name of the Data Platform Overview CloudWatch dashboard, or null when the stack is disabled. |
| <a name="output_pipeline_health_alarm_name"></a> [pipeline\_health\_alarm\_name](#output\_pipeline\_health\_alarm\_name) | Name of the composite Pipeline Health CloudWatch alarm, or null when the stack is disabled. |
| <a name="output_sns_kms_key_arn"></a> [sns\_kms\_key\_arn](#output\_sns\_kms\_key\_arn) | ARN of the KMS CMK used to encrypt both SNS topics, or null when the stack is disabled. |
| <a name="output_warning_sns_topic_arn"></a> [warning\_sns\_topic\_arn](#output\_warning\_sns\_topic\_arn) | ARN of the Warning SNS topic, or null when the stack is disabled. |
<!-- END_TF_DOCS -->

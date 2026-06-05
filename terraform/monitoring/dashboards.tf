# ---------------------------------------------------------------------------
# Dashboard body locals — widgets are built as any-typed locals using
# flatten() so Terraform does not attempt to unify tuple element types
# across the conditional branches. Each section is a list(any) that
# flatten() collapses into a single list before jsonencode().
# ---------------------------------------------------------------------------

locals {
  # --- Redshift widgets ---
  redshift_widgets = [
    {
      type       = "text"
      x          = 0
      y          = 0
      width      = 24
      height     = 1
      properties = { markdown = "## Redshift Serverless -- Data Warehouse" }
    },
    {
      type   = "metric"
      x      = 0
      y      = 1
      width  = 6
      height = 6
      properties = {
        title   = "Active Queries"
        view    = "timeSeries"
        region  = var.aws_region
        metrics = [["AWS/Redshift-Serverless", "QueriesRunning", "WorkgroupName", "${local.name}-warehouse-wg", { stat = "Maximum", period = 300 }]]
      }
    },
    {
      type   = "metric"
      x      = 6
      y      = 1
      width  = 6
      height = 6
      properties = {
        title   = "Query Failures"
        view    = "timeSeries"
        region  = var.aws_region
        metrics = [["AWS/Redshift-Serverless", "QueryFailed", "WorkgroupName", "${local.name}-warehouse-wg", { stat = "Sum", period = 600 }]]
      }
    },
    {
      type   = "metric"
      x      = 12
      y      = 1
      width  = 6
      height = 6
      properties = {
        title   = "Database Connections"
        view    = "timeSeries"
        region  = var.aws_region
        metrics = [["AWS/Redshift-Serverless", "DatabaseConnections", "WorkgroupName", "${local.name}-warehouse-wg", { stat = "Maximum", period = 300 }]]
      }
    },
    {
      type   = "metric"
      x      = 18
      y      = 1
      width  = 6
      height = 6
      properties = {
        title   = "Compute Usage (ComputeSeconds, hourly)"
        view    = "timeSeries"
        region  = var.aws_region
        metrics = [["AWS/Redshift-Serverless", "ComputeSeconds", "WorkgroupName", "${local.name}-warehouse-wg", { stat = "Sum", period = 3600 }]]
      }
    },
  ]

  # --- Athena widgets ---
  athena_widgets = [
    {
      type       = "text"
      x          = 0
      y          = 7
      width      = 24
      height     = 1
      properties = { markdown = "## Athena -- Query Engine" }
    },
    {
      type   = "metric"
      x      = 0
      y      = 8
      width  = 8
      height = 6
      properties = {
        title   = "Query Processing Time (p99)"
        view    = "timeSeries"
        region  = var.aws_region
        metrics = [["AWS/Athena", "ProcessingTime", { stat = "p99", period = 300 }]]
      }
    },
    {
      type   = "metric"
      x      = 8
      y      = 8
      width  = 8
      height = 6
      properties = {
        title   = "Data Scanned per Day (bytes)"
        view    = "timeSeries"
        region  = var.aws_region
        metrics = [["AWS/Athena", "ProcessedBytes", { stat = "Sum", period = 86400 }]]
      }
    },
    {
      type   = "metric"
      x      = 16
      y      = 8
      width  = 8
      height = 6
      properties = {
        title   = "Failed Queries (custom metric)"
        view    = "timeSeries"
        region  = var.aws_region
        metrics = [["Region20/Athena", "FailedQueries", { stat = "Sum", period = 600 }]]
      }
    },
  ]

  # --- Ingestion Pipeline widgets ---
  ingestion_widgets = [
    {
      type       = "text"
      x          = 0
      y          = 14
      width      = 24
      height     = 1
      properties = { markdown = "## Ingestion Pipeline -- Lambda and Glue" }
    },
    {
      type   = "metric"
      x      = 0
      y      = 15
      width  = 6
      height = 6
      properties = {
        title   = "gdrive-sync Invocations"
        view    = "timeSeries"
        region  = var.aws_region
        metrics = [["AWS/Lambda", "Invocations", "FunctionName", "${local.name}-gdrive-sync", { stat = "Sum", period = 300 }]]
      }
    },
    {
      type   = "metric"
      x      = 6
      y      = 15
      width  = 6
      height = 6
      properties = {
        title   = "gdrive-sync Errors"
        view    = "timeSeries"
        region  = var.aws_region
        metrics = [["AWS/Lambda", "Errors", "FunctionName", "${local.name}-gdrive-sync", { stat = "Sum", period = 300 }]]
      }
    },
    {
      type   = "metric"
      x      = 12
      y      = 15
      width  = 6
      height = 6
      properties = {
        title   = "gdrive-sync Duration (max)"
        view    = "timeSeries"
        region  = var.aws_region
        metrics = [["AWS/Lambda", "Duration", "FunctionName", "${local.name}-gdrive-sync", { stat = "Maximum", period = 300 }]]
      }
    },
    {
      type   = "metric"
      x      = 18
      y      = 15
      width  = 6
      height = 6
      properties = {
        title  = "Glue Crawler Failures (Connect20 + Ascender)"
        view   = "timeSeries"
        region = var.aws_region
        metrics = [
          ["Region20/Glue", "Connect20CrawlerFailure", { stat = "Sum", period = 300, label = "Connect20" }],
          ["Region20/Glue", "AscenderCrawlerFailure", { stat = "Sum", period = 300, label = "Ascender" }],
        ]
      }
    },
    {
      type   = "metric"
      x      = 0
      y      = 21
      width  = 12
      height = 6
      properties = {
        title  = "Glue Crawler Duration (Connect20 + Ascender, seconds)"
        view   = "timeSeries"
        region = var.aws_region
        metrics = [
          ["Region20/Glue", "Connect20CrawlerDuration", { stat = "Maximum", period = 300, label = "Connect20" }],
          ["Region20/Glue", "AscenderCrawlerDuration", { stat = "Maximum", period = 300, label = "Ascender" }],
        ]
      }
    },
  ]

  # --- S3 widgets ---
  s3_widgets = [
    {
      type       = "text"
      x          = 0
      y          = 27
      width      = 24
      height     = 1
      properties = { markdown = "## S3 Data Lake -- Object Counts (daily metric)" }
    },
    {
      type   = "metric"
      x      = 0
      y      = 28
      width  = 8
      height = 6
      properties = {
        title   = "Raw Bucket Object Count"
        view    = "timeSeries"
        region  = var.aws_region
        metrics = [["AWS/S3", "NumberOfObjects", "BucketName", "escr20-landing-zone-raw-${var.environment}", "StorageType", "AllStorageTypes", { stat = "Average", period = 86400 }]]
      }
    },
    {
      type   = "metric"
      x      = 8
      y      = 28
      width  = 8
      height = 6
      properties = {
        title   = "Bronze Bucket Object Count"
        view    = "timeSeries"
        region  = var.aws_region
        metrics = [["AWS/S3", "NumberOfObjects", "BucketName", "escr20-bronze-${var.environment}", "StorageType", "AllStorageTypes", { stat = "Average", period = 86400 }]]
      }
    },
    {
      type   = "metric"
      x      = 16
      y      = 28
      width  = 8
      height = 6
      properties = {
        title   = "Silver Bucket Object Count"
        view    = "timeSeries"
        region  = var.aws_region
        metrics = [["AWS/S3", "NumberOfObjects", "BucketName", "escr20-silver-${var.environment}", "StorageType", "AllStorageTypes", { stat = "Average", period = 86400 }]]
      }
    },
  ]

  # --- Conditional sections built as JSON strings ---
  # tolist() cannot unify objects with differently-shaped properties (metric vs log
  # widgets) or inner tuples with mixed element types (strings + objects in metrics
  # arrays). jsonencode() accepts any value without type unification, sidestepping
  # the constraint. jsondecode() at the resource level produces list(any) that
  # flatten() handles correctly.

  dbt_widgets_json = var.enable_dbt_ecs_monitoring ? jsonencode([
    {
      type       = "text"
      x          = 0
      y          = 0
      width      = 24
      height     = 1
      properties = { markdown = "## dbt ECS Fargate" }
    },
    {
      type   = "metric"
      x      = 0
      y      = 1
      width  = 12
      height = 6
      properties = {
        title   = "dbt ECS CPU Utilization"
        view    = "timeSeries"
        region  = var.aws_region
        metrics = [["AWS/ECS", "CPUUtilization", "ClusterName", "Reg20DBT${title(var.environment)}01", { stat = "Average", period = 300 }]]
      }
    },
    {
      type   = "metric"
      x      = 12
      y      = 1
      width  = 12
      height = 6
      properties = {
        title   = "dbt ECS Memory Utilization"
        view    = "timeSeries"
        region  = var.aws_region
        metrics = [["AWS/ECS", "MemoryUtilization", "ClusterName", "Reg20DBT${title(var.environment)}01", { stat = "Average", period = 300 }]]
      }
    },
  ]) : "[]"

  airbyte_ec2_widgets_json = var.enable_airbyte_monitoring ? jsonencode([
    {
      type       = "text"
      x          = 0
      y          = 7
      width      = 24
      height     = 1
      properties = { markdown = "## Airbyte EC2 Server" }
    },
    {
      type   = "metric"
      x      = 0
      y      = 8
      width  = 6
      height = 6
      properties = {
        title   = "Airbyte EC2 CPU Utilization"
        view    = "timeSeries"
        region  = var.aws_region
        metrics = [["AWS/EC2", "CPUUtilization", "InstanceId", data.aws_instance.airbyte[0].id, { stat = "Average", period = 300 }]]
      }
    },
    {
      type   = "metric"
      x      = 6
      y      = 8
      width  = 6
      height = 6
      properties = {
        title   = "Airbyte EC2 Memory Used %"
        view    = "timeSeries"
        region  = var.aws_region
        metrics = [["CWAgent", "mem_used_percent", "InstanceId", data.aws_instance.airbyte[0].id, { stat = "Average", period = 300 }]]
      }
    },
    {
      type   = "metric"
      x      = 12
      y      = 8
      width  = 6
      height = 6
      properties = {
        title   = "Airbyte EC2 Disk Used %"
        view    = "timeSeries"
        region  = var.aws_region
        metrics = [["CWAgent", "disk_used_percent", "InstanceId", data.aws_instance.airbyte[0].id, { stat = "Maximum", period = 300 }]]
      }
    },
    {
      type   = "log"
      x      = 18
      y      = 8
      width  = 6
      height = 6
      properties = {
        title  = "Airbyte Recent Logs"
        region = var.aws_region
        query  = "SOURCE '/airbyte/${local.name}-airbyte' | fields @timestamp, @message | sort @timestamp desc | limit 50"
        view   = "table"
      }
    },
  ]) : "[]"

  airbyte_rds_widgets_json = var.enable_airbyte_monitoring ? jsonencode([
    {
      type       = "text"
      x          = 0
      y          = 14
      width      = 24
      height     = 1
      properties = { markdown = "## Airbyte RDS PostgreSQL" }
    },
    {
      type   = "metric"
      x      = 0
      y      = 15
      width  = 6
      height = 6
      properties = {
        title   = "Airbyte DB CPU Utilization"
        view    = "timeSeries"
        region  = var.aws_region
        metrics = [["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", data.aws_db_instance.airbyte[0].id, { stat = "Average", period = 300 }]]
      }
    },
    {
      type   = "metric"
      x      = 6
      y      = 15
      width  = 6
      height = 6
      properties = {
        title   = "Airbyte DB Free Storage (bytes)"
        view    = "timeSeries"
        region  = var.aws_region
        metrics = [["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", data.aws_db_instance.airbyte[0].id, { stat = "Minimum", period = 300 }]]
      }
    },
    {
      type   = "metric"
      x      = 12
      y      = 15
      width  = 6
      height = 6
      properties = {
        title   = "Airbyte DB Connections"
        view    = "timeSeries"
        region  = var.aws_region
        metrics = [["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", data.aws_db_instance.airbyte[0].id, { stat = "Maximum", period = 300 }]]
      }
    },
    {
      type   = "metric"
      x      = 18
      y      = 15
      width  = 6
      height = 6
      properties = {
        title  = "Airbyte DB Read/Write Latency p99 (seconds)"
        view   = "timeSeries"
        region = var.aws_region
        metrics = [
          ["AWS/RDS", "ReadLatency", "DBInstanceIdentifier", data.aws_db_instance.airbyte[0].id, { stat = "p99", period = 300, label = "Read" }],
          ["AWS/RDS", "WriteLatency", "DBInstanceIdentifier", data.aws_db_instance.airbyte[0].id, { stat = "p99", period = 300, label = "Write" }],
        ]
      }
    },
  ]) : "[]"
}

# ---------------------------------------------------------------------------
# Dashboard 1: Data Platform Overview — always active
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_dashboard" "data_platform_overview" {
  count = var.create ? 1 : 0

  dashboard_name = "${local.name}-data-platform-overview"

  dashboard_body = jsonencode({
    widgets = flatten([
      local.redshift_widgets,
      local.athena_widgets,
      local.ingestion_widgets,
      local.s3_widgets,
    ])
  })
}

# ---------------------------------------------------------------------------
# Dashboard 2: Compute and Jobs — always created; sections conditional
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_dashboard" "compute_and_jobs" {
  count = var.create ? 1 : 0

  dashboard_name = "${local.name}-compute-and-jobs"

  dashboard_body = jsonencode({
    widgets = flatten([
      jsondecode(local.dbt_widgets_json),
      jsondecode(local.airbyte_ec2_widgets_json),
      jsondecode(local.airbyte_rds_widgets_json),
    ])
  })
}

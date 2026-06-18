locals {
  # Last updated: gdrive sync lambda permissions added
  data_engineer_prod_inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Statement1"
        Effect = "Allow"
        Action = [
          "sqlworkbench:ListConnections",
          "sqlworkbench:ListDatabases",
          "sqlworkbench:ListFiles",
          "sqlworkbench:ListNotebooks",
          "sqlworkbench:ListNotebookVersions",
          "sqlworkbench:ListRedshiftClusters",
          "sqlworkbench:ListQueryExecutionHistory",
          "sqlworkbench:ListSavedQueryVersions",
          "sqlworkbench:ListTabs",
          "sqlworkbench:BatchGetNotebookCell",
          "sqlworkbench:ExportNotebook",
          "sqlworkbench:GetAccountInfo",
          "sqlworkbench:GetAutocompletionMetadata",
          "sqlworkbench:GetAccountSettings",
          "sqlworkbench:GetAutocompletionResource",
          "sqlworkbench:GetConnection",
          "sqlworkbench:GetChart",
          "sqlworkbench:GetNotebook",
          "sqlworkbench:GetNotebookVersion",
          "sqlworkbench:GetQCustomContext",
          "sqlworkbench:GetQSqlPromptQuotas",
          "sqlworkbench:GetQSqlRecommendations",
          "sqlworkbench:GetQueryExecutionHistory",
          "sqlworkbench:GetSavedQuery",
          "sqlworkbench:GetSchemaInference",
          "sqlworkbench:GetSqlGenerationContext",
          "sqlworkbench:GetSqlRecommendations",
          "sqlworkbench:GetUserInfo",
          "sqlworkbench:GetUserWorkspaceSettings",
          "sqlworkbench:ListSampleDatabases",
          "sqlworkbench:ListTaggedResources",
          "sqlworkbench:ListTagsForResource",
          "sqlworkbench:TagResource",
          "sqlworkbench:UntagResource",
          "iam:Get*",
          "iam:List*",
          "iam:Tag*",
          "iam:CreateAccessKey",
          "iam:CreateRole",
          "iam:UpdateRole",
          "iam:UpdateRoleDescription",
          "iam:UpdateUser",
          "iam:AttachGroupPolicy",
          "iam:AttachRolePolicy",
          "iam:AttachUserPolicy",
          "iam:CreatePolicy",
          "iam:CreatePolicyVersion",
          "iam:DeleteRolePolicy",
          "iam:DeleteGroupPolicy",
          "iam:DeletePolicy",
          "iam:DeletePolicyVersion",
          "iam:PutGroupPolicy",
          "iam:PutRolePermissionsBoundary",
          "iam:PutRolePolicy",
          "iam:PutUserPermissionsBoundary",
          "iam:PutUserPolicy",
          "iam:UpdateAssumeRolePolicy",
          "secretsmanager:Get*",
          "secretsmanager:List*",
          "kms:Get*",
          "kms:List*",
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey",
          "athena:*",
          "lakeformation:Get*",
          "lakeformation:List*",
          "lakeformation:Describe*",
          "lakeformation:RevokePermissions",
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:GetTable",
          "glue:GetTables",
          "glue:GetPartition",
          "glue:GetPartitions",
          "glue:CreateTable",
          "glue:UpdateTable",
          "glue:DeleteTable",
          "glue:BatchCreatePartition",
          "glue:BatchDeletePartition",
          "cloudshell:*",
          # Lambda (TEA Google Drive sync)
          "lambda:CreateFunction",
          "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration",
          "lambda:GetFunction",
          "lambda:GetFunctionConfiguration",
          "lambda:InvokeFunction",
          "lambda:AddPermission",
          "lambda:RemovePermission",
          "lambda:DeleteFunction",
          "lambda:ListFunctions",
          "lambda:PublishLayerVersion",
          "lambda:GetLayerVersion",
          "lambda:DeleteLayerVersion",
          "lambda:ListLayers",
          "lambda:TagResource",
          # EventBridge (nightly cron trigger)
          "events:PutRule",
          "events:PutTargets",
          "events:DescribeRule",
          "events:ListRules",
          "events:ListTargetsByRule",
          "events:DeleteRule",
          "events:RemoveTargets",
          "events:EnableRule",
          "events:DisableRule",
          # SSM (incremental sync cursor + Session Manager console access)
          "ssm:*",
          # Secrets Manager (store tea.json SA key)
          "secretsmanager:CreateSecret",
          "secretsmanager:PutSecretValue",
          "secretsmanager:UpdateSecret",
          "secretsmanager:DeleteSecret",
          # S3 landing zone
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject",
          # CloudWatch Logs (Lambda execution logs)
          "logs:CreateLogGroup",
          "logs:CreateLogDelivery",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "glue:BatchDeletePartition",
          # ECS (run dbt Core tasks manually from console/CLI)
          "ecs:*",
          "iam:PassRole",
          # Cost Explorer
          "ce:*"
        ]
        Resource = ["*"]
    }]
  })
  data_engineer_dev_inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Statement1"
        Effect = "Allow"
        Action = [
          "sqlworkbench:ListConnections",
          "sqlworkbench:ListDatabases",
          "sqlworkbench:ListFiles",
          "sqlworkbench:ListNotebooks",
          "sqlworkbench:ListNotebookVersions",
          "sqlworkbench:ListRedshiftClusters",
          "sqlworkbench:ListQueryExecutionHistory",
          "sqlworkbench:ListSavedQueryVersions",
          "sqlworkbench:ListTabs",
          "sqlworkbench:BatchGetNotebookCell",
          "sqlworkbench:ExportNotebook",
          "sqlworkbench:GetAccountInfo",
          "sqlworkbench:GetAutocompletionMetadata",
          "sqlworkbench:GetAccountSettings",
          "sqlworkbench:GetAutocompletionResource",
          "sqlworkbench:GetConnection",
          "sqlworkbench:GetChart",
          "sqlworkbench:GetNotebook",
          "sqlworkbench:GetNotebookVersion",
          "sqlworkbench:GetQCustomContext",
          "sqlworkbench:GetQSqlPromptQuotas",
          "sqlworkbench:GetQSqlRecommendations",
          "sqlworkbench:GetQueryExecutionHistory",
          "sqlworkbench:GetSavedQuery",
          "sqlworkbench:GetSchemaInference",
          "sqlworkbench:GetSqlGenerationContext",
          "sqlworkbench:GetSqlRecommendations",
          "sqlworkbench:GetUserInfo",
          "sqlworkbench:GetUserWorkspaceSettings",
          "sqlworkbench:ListSampleDatabases",
          "sqlworkbench:ListTaggedResources",
          "sqlworkbench:ListTagsForResource",
          "sqlworkbench:TagResource",
          "sqlworkbench:UntagResource",
          "iam:Get*",
          "iam:List*",
          "iam:Tag*",
          "iam:CreateAccessKey",
          "iam:CreateRole",
          "iam:UpdateRole",
          "iam:UpdateRoleDescription",
          "iam:UpdateUser",
          "iam:AttachGroupPolicy",
          "iam:AttachRolePolicy",
          "iam:AttachUserPolicy",
          "iam:CreatePolicy",
          "iam:CreatePolicyVersion",
          "iam:DeleteRolePolicy",
          "iam:DeleteGroupPolicy",
          "iam:DeletePolicy",
          "iam:DeletePolicyVersion",
          "iam:PutGroupPolicy",
          "iam:PutRolePermissionsBoundary",
          "iam:PutRolePolicy",
          "iam:PutUserPermissionsBoundary",
          "iam:PutUserPolicy",
          "iam:UpdateAssumeRolePolicy",
          "secretsmanager:Get*",
          "secretsmanager:List*",
          "kms:Get*",
          "kms:List*",
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey",
          "athena:*",
          "lakeformation:Get*",
          "lakeformation:List*",
          "lakeformation:Describe*",
          "lakeformation:RevokePermissions",
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:GetTable",
          "glue:GetTables",
          "glue:GetPartition",
          "glue:GetPartitions",
          "glue:CreateTable",
          "glue:UpdateTable",
          "glue:DeleteTable",
          "glue:BatchCreatePartition",
          "glue:BatchDeletePartition",
          "cloudshell:*",
          # Lambda (TEA Google Drive sync)
          "lambda:CreateFunction",
          "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration",
          "lambda:GetFunction",
          "lambda:GetFunctionConfiguration",
          "lambda:InvokeFunction",
          "lambda:AddPermission",
          "lambda:RemovePermission",
          "lambda:DeleteFunction",
          "lambda:ListFunctions",
          "lambda:PublishLayerVersion",
          "lambda:GetLayerVersion",
          "lambda:DeleteLayerVersion",
          "lambda:ListLayers",
          "lambda:TagResource",
          # EventBridge (nightly cron trigger)
          "events:PutRule",
          "events:PutTargets",
          "events:DescribeRule",
          "events:ListRules",
          "events:ListTargetsByRule",
          "events:DeleteRule",
          "events:RemoveTargets",
          "events:EnableRule",
          "events:DisableRule",
          # SSM (incremental sync cursor + Session Manager console access)
          "ssm:*",
          # Secrets Manager (store tea.json SA key)
          "secretsmanager:CreateSecret",
          "secretsmanager:PutSecretValue",
          "secretsmanager:UpdateSecret",
          "secretsmanager:DeleteSecret",
          # S3 landing zone
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject",
          # CloudWatch Logs (Lambda execution logs)
          "logs:CreateLogGroup",
          "logs:CreateLogDelivery",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "glue:BatchDeletePartition",
          # ECS (run dbt Core tasks manually from console/CLI)
          "ecs:*",
          "iam:PassRole",
          # Cost Explorer
          "ce:*"
        ]
        Resource = ["*"]
      },
      #Allowing DE role to Direct S3 access to the raw files in raw bucket using Athena
      {
        Sid    = "ReadRawBucket"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:ListBucket"]
        Resource = [
          "arn:aws:s3:::escr20-landing-zone-raw-${var.environment}/*",
          "arn:aws:s3:::escr20-landing-zone-raw-${var.environment}",
        ]
      },
      # Redshift Query Editor v2 write/admin actions. Mirrors the
      # AmazonRedshiftQueryEditorV2FullAccess managed policy; lives inline
      # because the permission set already attaches the 10-policy IAM cap.
      # sqlworkbench:CreateAccount is the action behind the "Configure account"
      # screen users hit on first QEv2 access. tag:GetResources is required by
      # the editor to render resource tags. Read actions (sqlworkbench:Get*/List*)
      # are already granted in the Statement1 block above.
      {
        Sid    = "RedshiftQueryEditorV2"
        Effect = "Allow"
        Action = [
          "sqlworkbench:CreateAccount",
          "sqlworkbench:GetAccount",
          "sqlworkbench:UpdateAccountConnectionSettings",
          "sqlworkbench:UpdateAccountExportSettings",
          "sqlworkbench:UpdateAccountGeneralSettings",
          "sqlworkbench:UpdateAccountQSqlSettings",
          "sqlworkbench:PutUserWorkspaceSettings",
          "sqlworkbench:PutTab",
          "sqlworkbench:DeleteTab",
          "sqlworkbench:CreateFolder",
          "sqlworkbench:BatchDeleteFolder",
          "sqlworkbench:UpdateFileFolder",
          "sqlworkbench:GenerateSession",
          "sqlworkbench:DriverExecute",
          "sqlworkbench:CreateConnection",
          "sqlworkbench:UpdateConnection",
          "sqlworkbench:DeleteConnection",
          "sqlworkbench:AssociateConnectionWithTab",
          "sqlworkbench:AssociateConnectionWithChart",
          "sqlworkbench:CreateChart",
          "sqlworkbench:UpdateChart",
          "sqlworkbench:DeleteChart",
          "sqlworkbench:ListChartsForUser",
          "sqlworkbench:CreateSavedQuery",
          "sqlworkbench:UpdateSavedQuery",
          "sqlworkbench:DeleteSavedQuery",
          "sqlworkbench:CreateNotebook",
          "sqlworkbench:CreateNotebookCell",
          "sqlworkbench:CreateNotebookFromVersion",
          "sqlworkbench:CreateNotebookVersion",
          "sqlworkbench:DeleteNotebook",
          "sqlworkbench:DeleteNotebookVersion",
          "sqlworkbench:DuplicateNotebook",
          "sqlworkbench:ImportNotebook",
          "sqlworkbench:ListNotebooks",
          "sqlworkbench:RestoreNotebookVersion",
          "sqlworkbench:UpdateNotebook",
          "sqlworkbench:UpdateNotebookCellContent",
          "sqlworkbench:UpdateNotebookCellLayout",
          "sqlworkbench:UpdateNotebookVersion",
          "sqlworkbench:PutQCustomContext",
          "tag:GetResources",
        ]
        Resource = ["*"]
      },
    ]
  })

  # Flat map of (permission_set_key, managed_policy_short_name) -> object
  # used as for_each input for aws_ssoadmin_managed_policy_attachment.
  managed_policy_attachments = merge(
    {
      for arn in var.data_engineer_prod_permission_set.managed_policies :
      "prod:${reverse(split("/", arn))[0]}" => {
        permission_set_key = "prod"
        managed_policy_arn = arn
      }
    },
    {
      for arn in var.data_engineer_dev_permission_set.managed_policies :
      "dev:${reverse(split("/", arn))[0]}" => {
        permission_set_key = "dev"
        managed_policy_arn = arn
      }
    },
  )

  permission_set_arns = {
    prod = try(aws_ssoadmin_permission_set.data_engineer_prod[0].arn, null)
    dev  = try(aws_ssoadmin_permission_set.data_engineer_dev[0].arn, null)
  }
}

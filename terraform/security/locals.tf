locals {
  data_engineer_prod_inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Statement1"
        Effect = "Allow"
        Action = [
          "sqlworkbench:Get*",
          "sqlworkbench:List*",
          "iam:Get*",
          "iam:List*",
          "lakeformation:Get*",
          "lakeformation:Describe*",
          "lakeformation:List*",
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

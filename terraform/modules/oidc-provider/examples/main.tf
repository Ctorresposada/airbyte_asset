# Example usage of the terraform-aws-oidc-provider module

# Example 1: OIDC provider for specific repositories
module "github_oidc_specific_repos" {
  source = "../"

  role_name        = "github-actions-deployment-role"
  role_description = "IAM role for GitHub Actions deployments"

  # Restrict to specific repositories
  github_repositories = [
    "myorg/frontend-app",
    "myorg/backend-api"
  ]

  # Attach AWS managed policies
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/ReadOnlyAccess"
  ]

  # Optional: Attach a custom policy
  # attach_custom_policy = true
  # custom_policy_arn    = aws_iam_policy.custom_deployment_policy.arn

  max_session_duration = 3600 # 1 hour

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
    Purpose     = "github-actions-oidc"
  }
}

# Example 2: Organization-wide OIDC provider
module "github_oidc_org_wide" {
  source = "../"

  role_name        = "github-actions-org-role"
  role_description = "IAM role for all repositories in the organization"

  # Allow all repositories in the organization
  github_organization = "myorg"

  # Attach inline policy
  attach_inline_policy = true
  inline_policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = [
          "arn:aws:s3:::my-deployment-bucket",
          "arn:aws:s3:::my-deployment-bucket/*"
        ]
      }
    ]
  })

  max_session_duration = 7200 # 2 hours

  tags = {
    Environment = "production"
    Scope       = "organization"
  }
}

# Example 3: ECR push access for container deployments
module "github_oidc_ecr_push" {
  source = "../"

  role_name        = "github-actions-ecr-push-role"
  role_description = "IAM role for pushing container images to ECR"

  github_repositories = [
    "myorg/containerized-app"
  ]

  attach_inline_policy = true
  inline_policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = "arn:aws:ecr:us-east-1:123456789012:repository/my-app"
      }
    ]
  })

  tags = {
    Purpose = "ECR deployment"
  }
}

# Optional: Create a custom IAM policy to attach
# resource "aws_iam_policy" "custom_deployment_policy" {
#   name        = "CustomGitHubActionsDeploymentPolicy"
#   description = "Custom policy for GitHub Actions deployments"
#
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Action = [
#           "lambda:UpdateFunctionCode",
#           "lambda:UpdateFunctionConfiguration",
#           "lambda:PublishVersion"
#         ]
#         Resource = "arn:aws:lambda:us-east-1:123456789012:function:my-function"
#       }
#     ]
#   })
# }

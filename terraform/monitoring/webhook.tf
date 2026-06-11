# ---------------------------------------------------------------------------
# Airbyte webhook receiver — Private API Gateway + Lambda
#
# Airbyte calls this endpoint on every sync completion. The Lambda routes
# failures to the critical SNS topic and empty/unparseable payloads to
# the warning topic. The API Gateway is private: only reachable via the
# execute-api VPC endpoint already provisioned in the networking stack.
# ---------------------------------------------------------------------------

# Zip the handler source on apply when handler.py changes. terraform_data tracks
# the file hash as a resource attribute so replace_triggered_by fires reliably.
resource "terraform_data" "lambda_source_hash" {
  count = local.enable_webhook ? 1 : 0
  input = filebase64sha256("${path.module}/lambda/handler.py")
}

resource "archive_file" "airbyte_webhook" {
  count = local.enable_webhook ? 1 : 0

  type        = "zip"
  source_file = "${path.module}/lambda/handler.py"
  output_path = "/tmp/${local.name}-airbyte-webhook.zip"

  lifecycle {
    replace_triggered_by = [terraform_data.lambda_source_hash[0]]
  }
}

# ---------------------------------------------------------------------------
# CloudWatch log group — encrypted with the same KMS CMK used for SNS.
# The KMS key policy in data.tf grants logs.amazonaws.com access.
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "airbyte_webhook" {
  count = local.enable_webhook ? 1 : 0

  name              = "/aws/lambda/${local.name}-airbyte-webhook"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.sns[0].arn

  tags = {
    Name = "${local.name}-airbyte-webhook-logs"
  }
}

# ---------------------------------------------------------------------------
# Lambda function
# ---------------------------------------------------------------------------

resource "aws_lambda_function" "airbyte_webhook" {
  count = local.enable_webhook ? 1 : 0

  #checkov:skip=CKV_AWS_116:API Gateway invokes this Lambda synchronously; there is no async invocation path that would produce failed async events requiring a DLQ
  #checkov:skip=CKV_AWS_117:Lambda receives inbound API Gateway calls on a private VPC endpoint; it publishes to SNS via public AWS endpoints, so VPC placement is not required and would add NAT Gateway cost
  #checkov:skip=CKV_AWS_50:X-Ray tracing is intentionally omitted; CloudWatch logs provide sufficient observability for this low-frequency webhook receiver
  #checkov:skip=CKV_AWS_272:Code signing is not used in this repository; image integrity is ensured by the plan-artifact CI/CD workflow

  function_name = "${local.name}-airbyte-webhook"
  description   = "Receives Airbyte sync webhook events and routes failures to SNS"
  role          = aws_iam_role.airbyte_webhook[0].arn

  filename         = archive_file.airbyte_webhook[0].output_path
  source_code_hash = archive_file.airbyte_webhook[0].output_base64sha256

  runtime       = "python3.12"
  architectures = ["arm64"]
  handler       = "handler.lambda_handler"

  # Encrypt env vars with the same CMK used for SNS. The Lambda execution role
  # already has kms:GenerateDataKey + kms:Decrypt on this key via iam_webhook.tf.
  kms_key_arn = aws_kms_key.sns[0].arn

  reserved_concurrent_executions = 5

  environment {
    variables = {
      CRITICAL_TOPIC_ARN = aws_sns_topic.critical[0].arn
      WARNING_TOPIC_ARN  = aws_sns_topic.warning[0].arn
    }
  }

  tags = {
    Name = "${local.name}-airbyte-webhook"
  }

  depends_on = [aws_cloudwatch_log_group.airbyte_webhook]
}

# Allow API Gateway to invoke the Lambda.
resource "aws_lambda_permission" "apigateway_invoke" {
  count = local.enable_webhook ? 1 : 0

  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.airbyte_webhook[0].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.airbyte_webhook[0].execution_arn}/*/*"
}

# ---------------------------------------------------------------------------
# Private REST API
#
# The resource policy restricts invocations to requests arriving through the
# execute-api VPC endpoint. Any call from outside that endpoint is denied
# before it reaches the Lambda, providing network-level isolation without
# extra auth overhead.
# ---------------------------------------------------------------------------

resource "aws_api_gateway_rest_api" "airbyte_webhook" {
  count = local.enable_webhook ? 1 : 0

  #checkov:skip=CKV2_AWS_29:WAF is not required for a private API reachable only via VPC endpoint; the aws:SourceVpce resource policy already enforces network-level access control
  #checkov:skip=CKV_AWS_76:Access logging requires a separate CloudWatch log group ARN; the Lambda function log group provides equivalent observability for this low-volume webhook
  #checkov:skip=CKV_AWS_237:create_before_destroy on a REST API with count meta-argument causes a Terraform cycle; the VPC endpoint policy and short request volume mean brief API unavailability during redeploy is acceptable

  name        = "${local.name}-airbyte-webhook"
  description = "${local.name} private API for Airbyte sync webhook notifications"

  endpoint_configuration {
    types            = ["PRIVATE"]
    vpc_endpoint_ids = [data.aws_vpc_endpoint.execute_api[0].id]
  }

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "execute-api:Invoke"
        Resource  = "execute-api:/*"
        Condition = {
          StringEquals = {
            "aws:SourceVpce" = data.aws_vpc_endpoint.execute_api[0].id
          }
        }
      }
    ]
  })

  tags = {
    Name = "${local.name}-airbyte-webhook"
  }
}

# /webhook resource
resource "aws_api_gateway_resource" "webhook" {
  count = local.enable_webhook ? 1 : 0

  rest_api_id = aws_api_gateway_rest_api.airbyte_webhook[0].id
  parent_id   = aws_api_gateway_rest_api.airbyte_webhook[0].root_resource_id
  path_part   = "webhook"
}

# POST method — no authorization; network isolation is enforced by the VPC endpoint policy.
resource "aws_api_gateway_method" "webhook_post" {
  count = local.enable_webhook ? 1 : 0

  #checkov:skip=CKV_AWS_59:NONE authorization is intentional; the API is private and reachable only via the execute-api VPC endpoint enforced by the aws:SourceVpce resource policy
  #checkov:skip=CKV2_AWS_53:API Gateway request validation omitted; the Lambda handler validates all payloads and routes unknown or malformed structures to the warning SNS topic

  rest_api_id   = aws_api_gateway_rest_api.airbyte_webhook[0].id
  resource_id   = aws_api_gateway_resource.webhook[0].id
  http_method   = "POST"
  authorization = "NONE"
}

# Lambda proxy integration — passes the full event to the handler.
resource "aws_api_gateway_integration" "webhook_post" {
  count = local.enable_webhook ? 1 : 0

  rest_api_id             = aws_api_gateway_rest_api.airbyte_webhook[0].id
  resource_id             = aws_api_gateway_resource.webhook[0].id
  http_method             = aws_api_gateway_method.webhook_post[0].http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.airbyte_webhook[0].invoke_arn
}

# Deployment — the triggers block forces a new deployment when the handler
# source changes or when the method/integration configuration changes.
resource "aws_api_gateway_deployment" "airbyte_webhook" {
  count = local.enable_webhook ? 1 : 0

  rest_api_id = aws_api_gateway_rest_api.airbyte_webhook[0].id

  triggers = {
    handler_hash = md5(file("${path.module}/lambda/handler.py"))
  }

  depends_on = [
    aws_api_gateway_method.webhook_post,
    aws_api_gateway_integration.webhook_post,
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "airbyte_webhook" {
  count = local.enable_webhook ? 1 : 0

  #checkov:skip=CKV_AWS_73:X-Ray tracing omitted; Lambda CloudWatch logs provide sufficient observability for this low-frequency private webhook
  #checkov:skip=CKV_AWS_76:Stage-level access logging omitted; Lambda CloudWatch logs capture all request/response details for this low-volume private endpoint
  #checkov:skip=CKV2_AWS_4:Stage-level method execution logging omitted; all request details are captured in the Lambda CloudWatch log group for this low-volume private webhook
  #checkov:skip=CKV2_AWS_51:Client certificate authentication is not applicable for Airbyte webhook calls; network isolation via VPC endpoint resource policy enforces access control
  #checkov:skip=CKV_AWS_120:Cache is not enabled; this is a low-volume inbound webhook that must not cache POST responses

  rest_api_id   = aws_api_gateway_rest_api.airbyte_webhook[0].id
  deployment_id = aws_api_gateway_deployment.airbyte_webhook[0].id
  stage_name    = "v1"

  tags = {
    Name = "${local.name}-airbyte-webhook-v1"
  }
}

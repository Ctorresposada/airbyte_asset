data "aws_caller_identity" "this" {
  count = var.create ? 1 : 0
}

data "aws_caller_identity" "second" {
  count = var.environment == "prod" ? 1 : 0
}

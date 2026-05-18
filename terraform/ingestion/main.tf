data "aws_caller_identity" "this" {
  count = var.create ? 1 : 0
}

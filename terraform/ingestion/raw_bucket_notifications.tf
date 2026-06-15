# ---------------------------------------------------------------------------
# S3 event notifications for the raw bucket (tea/ prefix)
#
# AWS allows only one aws_s3_bucket_notification per bucket. A second Terraform
# resource targeting the same bucket silently overwrites the first one on apply.
# All raw-bucket Lambda triggers live here; add extra lambda_function blocks
# rather than creating a new resource.
#
# Two triggers with non-overlapping suffixes (S3 rejects overlapping filter pairs
# on the same prefix):
#  .csv files dropped in raw/tea/ → fires tea_bronze_router Lambda
#  .pdf files dropped in raw/tea/ → fires pdf_to_bronze Lambda 
# ---------------------------------------------------------------------------
resource "aws_s3_bucket_notification" "raw_tea_notifications" {
  count = var.create ? 1 : 0

  bucket = aws_s3_bucket.buckets["raw"].id

  lambda_function {
    lambda_function_arn = aws_lambda_function.pdf_to_bronze[0].arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = var.pdf_extraction_s3_prefix
    filter_suffix       = ".pdf"
  }

  lambda_function {
    lambda_function_arn = aws_lambda_function.tea_bronze_router[0].arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "tea/"
    filter_suffix       = ".csv"
  }

  depends_on = [
    aws_lambda_permission.pdf_to_bronze_s3,
    aws_lambda_permission.tea_bronze_router_s3,
  ]
}

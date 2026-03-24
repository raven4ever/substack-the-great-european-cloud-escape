resource "aws_s3_bucket" "input" {
  bucket_prefix = "image-resizer-input-"
  force_destroy = true

  tags = {
    Project = "ep2-lambda-to-from-s3"
  }
}

resource "aws_s3_bucket" "output" {
  bucket_prefix = "image-resizer-output-"
  force_destroy = true

  tags = {
    Project = "ep2-lambda-to-from-s3"
  }
}

resource "aws_s3_bucket_notification" "input" {
  bucket = aws_s3_bucket.input.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.resizer.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.s3]
}

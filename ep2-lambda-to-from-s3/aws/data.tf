data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "lambda_s3" {
  statement {
    actions = [
      "s3:GetObject",
    ]
    resources = [format("%s/*", aws_s3_bucket.input.arn)]
  }

  statement {
    actions = [
      "s3:PutObject",
    ]
    resources = [format("%s/*", aws_s3_bucket.output.arn)]
  }
}

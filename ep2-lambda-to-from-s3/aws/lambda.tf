resource "terraform_data" "lambda_package" {
  triggers_replace = [
    filemd5(format("%s/requirements.txt", local.lambda_source)),
    filemd5(format("%s/handler.py", local.lambda_source)),
  ]

  provisioner "local-exec" {
    command = <<-EOT
      cd ${abspath(local.lambda_source)}
      docker run --rm --platform linux/amd64 -v $(pwd):/var/task --workdir /var/task \
        public.ecr.aws/sam/build-python3.13:latest \
        pip install -r requirements.txt --target ./package --quiet
      cd package && zip -r ${abspath(local.lambda_package)} . -q
      cd ${abspath(local.lambda_source)}
      zip ${abspath(local.lambda_package)} handler.py -q
      rm -rf package
    EOT
  }
}

resource "aws_lambda_function" "resizer" {
  function_name    = local.function_name
  role             = aws_iam_role.lambda.arn
  handler          = local.lambda_handler
  runtime          = local.lambda_runtime
  timeout          = 30
  memory_size      = 256
  filename         = local.lambda_package
  source_code_hash = terraform_data.lambda_package.id

  environment {
    variables = {
      DEST_BUCKET      = aws_s3_bucket.output.id
      THUMBNAIL_WIDTH  = "200"
      THUMBNAIL_HEIGHT = "200"
    }
  }

  tags = {
    Project = "ep2-lambda-to-from-s3"
  }

  depends_on = [terraform_data.lambda_package]
}

resource "aws_lambda_permission" "s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.resizer.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.input.arn
}

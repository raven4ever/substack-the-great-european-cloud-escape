resource "null_resource" "lambda_package" {
  triggers = {
    requirements = filemd5(format("%s/requirements.txt", local.lambda_source))
    handler      = filemd5(format("%s/handler.py", local.lambda_source))
  }

  provisioner "local-exec" {
    command = <<-EOT
      cd ${local.lambda_source}
      pip install -r requirements.txt --target ./package --platform manylinux2014_x86_64 --only-binary=:all: --quiet
      cp handler.py package/
      cd package
      zip -r ${abspath(local.lambda_package)} . --quiet
      cd ..
      rm -rf package
    EOT
  }
}

data "local_file" "lambda_zip" {
  filename   = local.lambda_package
  depends_on = [null_resource.lambda_package]
}

resource "aws_lambda_function" "resizer" {
  function_name    = local.function_name
  role             = aws_iam_role.lambda.arn
  handler          = local.lambda_handler
  runtime          = local.lambda_runtime
  timeout          = 30
  memory_size      = 256
  filename         = local.lambda_package
  source_code_hash = data.local_file.lambda_zip.content_base64sha256

  environment {
    variables = {
      DEST_BUCKET     = aws_s3_bucket.output.id
      THUMBNAIL_WIDTH = "200"
      THUMBNAIL_HEIGHT = "200"
    }
  }

  tags = {
    Project = "ep2-lambda-to-from-s3"
  }

  depends_on = [null_resource.lambda_package]
}

resource "aws_lambda_permission" "s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.resizer.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.input.arn
}

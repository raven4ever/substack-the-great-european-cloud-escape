locals {
  function_name  = "image-resizer"
  lambda_handler = "handler.aws_handler"
  lambda_runtime = "python3.14"
  lambda_source  = format("%s/../lambda", path.module)
  lambda_package = format("%s/package.zip", path.module)
}

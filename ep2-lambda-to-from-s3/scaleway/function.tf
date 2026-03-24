resource "scaleway_function_namespace" "main" {
  name        = "image-resizer"
  description = "Image thumbnail generator"

  tags = ["ep2-lambda-to-from-s3"]
}

resource "null_resource" "function_package" {
  triggers = {
    requirements = filemd5(format("%s/requirements.txt", local.function_source))
    handler      = filemd5(format("%s/handler.py", local.function_source))
  }

  provisioner "local-exec" {
    command = <<-EOT
      cd ${local.function_source}
      pip install -r requirements.txt --target ./package --platform manylinux2014_x86_64 --only-binary=:all: --quiet
      cp handler.py package/
      cd package
      zip -r ${abspath(local.function_package)} . --quiet
      cd ..
      rm -rf package
    EOT
  }
}

resource "scaleway_function" "resizer" {
  namespace_id = scaleway_function_namespace.main.id
  name         = local.function_name
  handler      = local.function_handler
  runtime      = local.function_runtime
  privacy      = "private"
  timeout      = 30
  memory_limit = 256
  min_scale    = 0
  max_scale    = 5
  zip_file     = local.function_package
  zip_hash     = filemd5(local.function_package)
  deploy       = true

  environment_variables = {
    DEST_BUCKET      = scaleway_object_bucket.output.name
    S3_ENDPOINT      = format("https://s3.%s.scw.cloud", scaleway_object_bucket.output.region)
    THUMBNAIL_WIDTH  = "200"
    THUMBNAIL_HEIGHT = "200"
  }

  secret_environment_variables = {
    AWS_ACCESS_KEY_ID     = var.scw_access_key
    AWS_SECRET_ACCESS_KEY = var.scw_secret_key
  }

  depends_on = [null_resource.function_package]
}

resource "scaleway_function_trigger" "sqs" {
  function_id = scaleway_function.resizer.id
  name        = "image-upload-trigger"

  sqs {
    queue = scaleway_mnq_sqs_queue.images.name
  }
}

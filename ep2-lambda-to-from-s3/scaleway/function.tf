resource "scaleway_function_namespace" "main" {
  name        = "image-resizer"
  description = "Image thumbnail generator"

  tags = ["ep2-lambda-to-from-s3"]
}

resource "terraform_data" "function_package" {
  triggers_replace = [
    filemd5(format("%s/requirements.txt", local.function_source)),
    filemd5(format("%s/handler.py", local.function_source)),
  ]

  provisioner "local-exec" {
    command = <<-EOT
      cd ${local.function_source}
      docker run --rm -v $(pwd):/home/app/function --workdir /home/app/function \
        rg.fr-par.scw.cloud/scwfunctionsruntimes-public/python-dep:3.13 \
        pip install -r requirements.txt --target ./package
      mkdir -p package/handlers && cp handler.py package/handlers/
      cd package && zip -r ${abspath(local.function_package)} . -q && cd .. && rm -rf package
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
  zip_hash     = terraform_data.function_package.id
  deploy       = true

  environment_variables = {
    DEST_BUCKET      = scaleway_object_bucket.output.name
    S3_ENDPOINT      = scaleway_object_bucket.output.api_endpoint
    THUMBNAIL_WIDTH  = "200"
    THUMBNAIL_HEIGHT = "200"
  }

  secret_environment_variables = {
    AWS_ACCESS_KEY_ID     = scaleway_iam_api_key.function.access_key
    AWS_SECRET_ACCESS_KEY = scaleway_iam_api_key.function.secret_key
  }

  depends_on = [terraform_data.function_package]
}

resource "scaleway_function_trigger" "sqs" {
  function_id = scaleway_function.resizer.id
  name        = "image-upload-trigger"

  sqs {
    queue = scaleway_mnq_sqs_queue.images.name
  }
}

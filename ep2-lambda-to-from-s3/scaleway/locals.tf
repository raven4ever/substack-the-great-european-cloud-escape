locals {
  function_name    = "image-resizer"
  function_handler = "handlers/handler.scaleway_handler"
  function_runtime = "python313"
  function_source  = format("%s/../lambda", path.module)
  function_package = format("%s/package.zip", path.module)
}

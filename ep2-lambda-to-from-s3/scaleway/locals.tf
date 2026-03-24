locals {
  function_name    = "image-resizer"
  function_handler = "handler.scaleway_handler"
  function_runtime = "python314"
  function_source  = format("%s/../lambda", path.module)
  function_package = format("%s/package.zip", path.module)
}

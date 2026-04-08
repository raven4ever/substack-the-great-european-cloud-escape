locals {
  app_name      = "ep3-app"
  instance_type = "t2.micro"
  app_dir       = format("%s/../app", path.module)
}

# create an S3 bucket
resource "scaleway_object_bucket" "main" {
  name          = "my-super-super-uber-scaleway-website-bucket"
  force_destroy = true

  versioning {
    enabled = true
  }
  
  tags = {
    Project = "my-super-super-uber-scaleway-website"
  }
}

# allow public read
resource "scaleway_object_bucket_acl" "main" {
  bucket = scaleway_object_bucket.main.id
  acl    = "public-read"
}

# upload the files
resource "scaleway_object" "website_files" {
  for_each     = fileset("${path.module}/../website", "**")
  bucket       = scaleway_object_bucket.main.id
  key          = each.key
  file         = format("%s/../website/%s", path.module, each.key)
  visibility   = "public-read"
  content_type = lookup(local.mime_map, reverse(split(".", each.key))[0], "text/plain")
  hash         = filemd5(format("%s/../website/%s", path.module, each.key))
  tags = {
    Project = "my-super-super-uber-scaleway-website"
  }
}

# configure the bucket as website
resource "scaleway_object_bucket_website_configuration" "website" {
  bucket = scaleway_object_bucket.main.id
  index_document {
    suffix = "index.html"
  }
  error_document {
    key = "error.html"
  }
}

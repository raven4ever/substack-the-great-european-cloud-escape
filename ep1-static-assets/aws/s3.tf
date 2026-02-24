# create an S3 bucket
resource "aws_s3_bucket" "main" {
  bucket        = "my-super-super-uber-aws-website-bucket"
  force_destroy = true

  tags = {
    Project = "my-super-super-uber-aws-website"
  }
}

# allow public read
resource "aws_s3_bucket_acl" "main" {
  bucket = aws_s3_bucket.main.id
  acl    = "public-read"
}

# set the bucket policy
resource "aws_s3_bucket_policy" "main" {
  bucket = aws_s3_bucket.main.bucket
  policy = data.aws_iam_policy_document.origin_bucket_policy.json
}

# upload the files
resource "aws_s3_object" "website_files" {
  for_each     = fileset("${path.module}/../website", "**")
  bucket       = aws_s3_bucket.main.id
  key          = each.key
  source       = format("%s/../website/%s", path.module, each.key)
  content_type = lookup(local.mime_map, reverse(split(".", each.key))[0], "text/plain")
  etag         = filemd5(format("%s/../website/%s", path.module, each.key))
  acl          = "public-read"
  tags = {
    Project = "my-super-super-uber-aws-website"
  }
}

# configure the bucket as website
resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.main.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

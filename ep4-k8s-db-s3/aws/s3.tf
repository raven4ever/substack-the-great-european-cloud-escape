resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "animal_images" {
  bucket = format("%s-animal-images-%s", local.app_name, random_id.bucket_suffix.hex)

  tags = {
    Name    = format("%s-animal-images", local.app_name)
    Project = local.project
  }
}

resource "aws_s3_bucket_public_access_block" "animal_images" {
  bucket = aws_s3_bucket.animal_images.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "animal_images" {
  bucket = aws_s3_bucket.animal_images.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

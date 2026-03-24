resource "scaleway_object_bucket" "input" {
  name          = "image-resizer-input"
  force_destroy = true

  tags = {
    Project = "ep2-lambda-to-from-s3"
  }
}

resource "scaleway_object_bucket" "output" {
  name          = "image-resizer-output"
  force_destroy = true

  tags = {
    Project = "ep2-lambda-to-from-s3"
  }
}

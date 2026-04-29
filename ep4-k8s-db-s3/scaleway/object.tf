resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "scaleway_object_bucket" "animal_images" {
  name = format("%s-animal-images-%s", local.app_name, random_id.bucket_suffix.hex)
  tags = {
    Project = local.project
  }
}

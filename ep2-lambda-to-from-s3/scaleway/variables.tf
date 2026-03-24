variable "scw_access_key" {
  description = "Scaleway access key for the function to access Object Storage"
  type        = string
  sensitive   = true
}

variable "scw_secret_key" {
  description = "Scaleway secret key for the function to access Object Storage"
  type        = string
  sensitive   = true
}

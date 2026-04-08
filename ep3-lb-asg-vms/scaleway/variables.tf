variable "vm_password" {
  description = "Password for the VM instance"
  type        = string
  sensitive   = true
  default     = "my-password"
}

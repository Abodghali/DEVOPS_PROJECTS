variable "region" {
  description = "AWS region for the backup bucket."
  type        = string
  default     = "eu-central-1"
}
variable "bucket_name" {
  description = "Globally unique bucket name."
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "Use 3-63 lowercase letters, digits or hyphens, starting and ending with a letter or digit."
  }
}

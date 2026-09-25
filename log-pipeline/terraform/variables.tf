variable "region" {
  type    = string
  default = "eu-central-1"
}
variable "admin_cidr" {
  description = "Operator public IPv4 address as a /32 network."
  type        = string
  validation {
    condition     = can(cidrnetmask(var.admin_cidr)) && endswith(var.admin_cidr, "/32")
    error_message = "Use your public IPv4 address followed by /32."
  }
}
variable "ssh_public_key" {
  description = "Existing SSH public key, never the private key."
  type        = string
}

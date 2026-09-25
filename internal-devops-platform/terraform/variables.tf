variable "region" {
  type    = string
  default = "eu-central-1"
}
variable "name" { type = string }
variable "admin_cidr" {
  type = string
  validation {
    condition     = can(cidrnetmask(var.admin_cidr)) && endswith(var.admin_cidr, "/32")
    error_message = "Use your public IPv4 address with /32."
  }
}
variable "admin_principal_arn" { type = string }
variable "ssh_public_key" { type = string }
variable "enable_ingress" {
  type    = bool
  default = false
}
variable "public_ingress" {
  type    = bool
  default = false
}

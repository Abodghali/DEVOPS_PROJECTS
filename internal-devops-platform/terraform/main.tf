terraform {
  required_version = ">= 1.10, < 2.0"
  backend "s3" {}
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
provider "aws" {
  region = var.region
  default_tags {
    tags = { Project = var.name, ManagedBy = "terraform", Purpose = "portfolio-lab" }
  }
}
module "cluster" {
  source              = "./modules/cluster"
  name                = var.name
  admin_cidr          = var.admin_cidr
  admin_principal_arn = var.admin_principal_arn
  ssh_public_key      = var.ssh_public_key
  enable_ingress      = var.enable_ingress
  public_ingress      = var.public_ingress
}
output "cluster_name" { value = module.cluster.cluster_name }
output "runner_ip" { value = module.cluster.runner_ip }
output "load_balancer_dns" { value = module.cluster.load_balancer_dns }
output "ansible_inventory" { value = "[runners]\nrunner ansible_host=${module.cluster.runner_ip} ansible_user=ubuntu\n" }

output "runner_private_ip" { value = module.cluster.runner_private_ip }

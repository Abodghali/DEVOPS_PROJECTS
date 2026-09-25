terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
variable "name" { type = string }
variable "admin_cidr" { type = string }
variable "admin_principal_arn" { type = string }
variable "ssh_public_key" { type = string }
variable "enable_ingress" { type = bool }
variable "public_ingress" { type = bool }
data "aws_availability_zones" "available" { state = "available" }
resource "aws_vpc" "main" {
  cidr_block           = "10.70.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = var.name }
}
resource "aws_subnet" "nodes" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags                    = { "kubernetes.io/role/elb" = "1" }
}
resource "aws_internet_gateway" "main" { vpc_id = aws_vpc.main.id }
resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}
resource "aws_route_table_association" "nodes" {
  count          = 2
  subnet_id      = aws_subnet.nodes[count.index].id
  route_table_id = aws_route_table.main.id
}
resource "aws_iam_role" "cluster" {
  name_prefix        = "eks-control-"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "eks.amazonaws.com" }, Action = "sts:AssumeRole" }] })
}
resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}
resource "aws_eks_cluster" "main" {
  name     = var.name
  role_arn = aws_iam_role.cluster.arn
  version  = "1.34"
  access_config { authentication_mode = "API_AND_CONFIG_MAP" }
  vpc_config {
    subnet_ids              = aws_subnet.nodes[*].id
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = [var.admin_cidr]
  }
  depends_on = [aws_iam_role_policy_attachment.cluster]
}
resource "aws_iam_role" "nodes" {
  name_prefix        = "eks-nodes-"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }] })
}
resource "aws_iam_role_policy_attachment" "nodes" {
  for_each   = toset(["AmazonEKSWorkerNodePolicy", "AmazonEC2ContainerRegistryReadOnly", "AmazonEKS_CNI_Policy"])
  role       = aws_iam_role.nodes.name
  policy_arn = "arn:aws:iam::aws:policy/${each.value}"
}
resource "aws_eks_node_group" "main" {
  cluster_name   = aws_eks_cluster.main.name
  node_role_arn  = aws_iam_role.nodes.arn
  subnet_ids     = aws_subnet.nodes[*].id
  instance_types = ["t3.large"]
  disk_size      = 40
  scaling_config {
    desired_size = 3
    min_size     = 3
    max_size     = 6
  }
  update_config { max_unavailable = 1 }
  depends_on = [aws_iam_role_policy_attachment.nodes, aws_route_table_association.nodes]
}
resource "aws_eks_access_entry" "admin" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = var.admin_principal_arn
}
resource "aws_eks_access_policy_association" "admin" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_eks_access_entry.admin.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  access_scope { type = "cluster" }
}
resource "aws_eks_addon" "identity" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "eks-pod-identity-agent"
  depends_on   = [aws_eks_node_group.main]
}
resource "aws_iam_role" "storage" {
  name_prefix        = "eks-storage-"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "pods.eks.amazonaws.com" }, Action = ["sts:AssumeRole", "sts:TagSession"] }] })
}
resource "aws_iam_role_policy_attachment" "storage" {
  role       = aws_iam_role.storage.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicyV2"
}
resource "aws_eks_pod_identity_association" "storage" {
  cluster_name    = aws_eks_cluster.main.name
  namespace       = "kube-system"
  service_account = "ebs-csi-controller-sa"
  role_arn        = aws_iam_role.storage.arn
  depends_on      = [aws_eks_addon.identity]
}
resource "aws_eks_addon" "storage" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "aws-ebs-csi-driver"
  depends_on   = [aws_eks_pod_identity_association.storage, aws_iam_role_policy_attachment.storage]
}
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}
resource "aws_security_group" "runner" {
  name_prefix = "ci-runner-"
  vpc_id      = aws_vpc.main.id

}
resource "aws_key_pair" "runner" {
  key_name_prefix = "ci-runner-"
  public_key      = var.ssh_public_key
}
resource "aws_instance" "runner" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.medium"
  subnet_id              = aws_subnet.nodes[0].id
  vpc_security_group_ids = [aws_security_group.runner.id]
  key_name               = aws_key_pair.runner.key_name
  metadata_options { http_tokens = "required" }
  root_block_device {
    encrypted   = true
    volume_size = 40
    volume_type = "gp3"
  }
  tags = { Name = "${var.name}-runner" }
}
resource "aws_lb" "ingress" {
  count                            = var.enable_ingress ? 1 : 0
  name_prefix                      = "lab-"
  internal                         = !var.public_ingress
  load_balancer_type               = "network"
  subnets                          = aws_subnet.nodes[*].id
  enable_cross_zone_load_balancing = true
}
resource "aws_lb_target_group" "ingress" {
  count              = var.enable_ingress ? 1 : 0
  port               = 30080
  protocol           = "TCP"
  vpc_id             = aws_vpc.main.id
  preserve_client_ip = false
  health_check { protocol = "TCP" }
}
resource "aws_lb_listener" "ingress" {
  count             = var.enable_ingress ? 1 : 0
  load_balancer_arn = aws_lb.ingress[0].arn
  port              = 80
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ingress[0].arn
  }
}
resource "aws_autoscaling_attachment" "ingress" {
  count                  = var.enable_ingress ? 1 : 0
  autoscaling_group_name = aws_eks_node_group.main.resources[0].autoscaling_groups[0].name
  lb_target_group_arn    = aws_lb_target_group.ingress[0].arn
}
resource "aws_security_group_rule" "ingress" {
  count             = var.enable_ingress ? 1 : 0
  type              = "ingress"
  security_group_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  from_port         = 30080
  to_port           = 30080
  protocol          = "tcp"
  cidr_blocks       = [aws_vpc.main.cidr_block]
}
output "cluster_name" { value = aws_eks_cluster.main.name }
output "runner_ip" { value = aws_instance.runner.public_ip }
output "load_balancer_dns" { value = try(aws_lb.ingress[0].dns_name, null) }

resource "aws_security_group_rule" "runner_api" {
  type                     = "ingress"
  security_group_id        = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  source_security_group_id = aws_security_group.runner.id
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
}
resource "aws_security_group_rule" "runner_metrics" {
  for_each          = toset(["9100", "9252"])
  type              = "ingress"
  security_group_id = aws_security_group.runner.id
  from_port         = tonumber(each.value)
  to_port           = tonumber(each.value)
  protocol          = "tcp"
  cidr_blocks       = [aws_vpc.main.cidr_block]
}
output "runner_private_ip" { value = aws_instance.runner.private_ip }

resource "aws_eks_addon" "network_policy" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "vpc-cni"
  configuration_values        = jsonencode({ enableNetworkPolicy = "true" })
  resolve_conflicts_on_create = "OVERWRITE"
  depends_on                  = [aws_eks_node_group.main]
}

resource "aws_security_group_rule" "runner_ssh" {
  type              = "ingress"
  security_group_id = aws_security_group.runner.id
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [var.admin_cidr]
}
resource "aws_security_group_rule" "runner_outbound" {
  type              = "egress"
  security_group_id = aws_security_group.runner.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

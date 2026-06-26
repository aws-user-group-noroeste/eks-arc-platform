# -----------------------------------------------------------------------------
# VPC Module - Main Configuration
# Wraps terraform-aws-modules/vpc/aws with EKS discovery tags
# -----------------------------------------------------------------------------

data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "zone-name"
    values = ["us-east-1a", "us-east-1b", "us-east-1c"]
  }
}

locals {
  azs = data.aws_availability_zones.available.names
}

# Precondition: at least 2 AZs must be available in the region.
# This prevents partial subnet creation that would break EKS.
resource "terraform_data" "az_check" {
  lifecycle {
    precondition {
      condition     = length(local.azs) >= 2
      error_message = "At least 2 availability zones are required in the selected region, but only ${length(local.azs)} are available. EKS requires subnets in multiple AZs."
    }
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.17"

  depends_on = [terraform_data.az_check]

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 4, i)]
  public_subnets  = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 4, i + length(local.azs))]

  enable_nat_gateway     = true
  single_nat_gateway     = var.nat_gateway_count == 1
  one_nat_gateway_per_az = var.nat_gateway_count >= length(local.azs)

  enable_dns_hostnames = true
  enable_dns_support   = true

  # Disable default resource management — incompatible with AWS provider >= 5.87
  manage_default_network_acl    = false
  manage_default_route_table    = false
  manage_default_security_group = false

  # Discovery tags for EKS load balancers and Karpenter
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
    "karpenter.sh/discovery"          = var.cluster_name
  }

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

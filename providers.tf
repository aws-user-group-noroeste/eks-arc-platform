# -----------------------------------------------------------------------------
# Provider Configuration
# Requirements: 3.4 (IRSA/OIDC via exec auth), 6.3 (sensitive credential boundary)
# -----------------------------------------------------------------------------

provider "aws" {
  region = var.aws_region

  assume_role {
    role_arn = var.terraform_execution_role_arn
  }

  default_tags {
    tags = local.common_tags
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.aws_region, "--role-arn", var.terraform_execution_role_arn]
  }
}

provider "helm" {
  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.aws_region, "--role-arn", var.terraform_execution_role_arn]
    }
  }
}

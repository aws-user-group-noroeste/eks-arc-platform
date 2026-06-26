# -----------------------------------------------------------------------------
# Root Module Wiring
# Instantiates all child modules and enforces explicit dependency ordering so
# that a single `terraform apply` provisions the full stack and `terraform
# destroy` tears it down in the correct reverse order.
#
# Apply order:
#   VPC → EKS → Karpenter (IAM/SQS → Helm → NodePool)
#            → Secrets Store CSI Driver + ASCP
#            → Secrets (IRSA + KMS → Secrets Manager Secret)
#            → ARC controller
#            → Runner Scale Set (SecretProviderClass + Helm)
#
# Destroy order (reverse):
#   Runner Scale Set + SecretProviderClass + Karpenter/NodePool removed before
#   EKS cluster deletion
#
# Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 10.6
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# 1. VPC — foundation layer, no upstream dependencies
# -----------------------------------------------------------------------------
module "vpc" {
  source = "./modules/vpc"

  vpc_cidr          = var.vpc_cidr
  cluster_name      = local.cluster_name
  nat_gateway_count = var.nat_gateway_count
}

# -----------------------------------------------------------------------------
# 2. EKS — depends on VPC for networking
# -----------------------------------------------------------------------------
module "eks" {
  source = "./modules/eks"

  cluster_name                 = local.cluster_name
  kubernetes_version           = var.kubernetes_version
  vpc_id                       = module.vpc.vpc_id
  subnet_ids                   = module.vpc.private_subnet_ids
  system_node_group_max_size   = var.system_node_group_max_size
  cluster_admin_arn            = var.cluster_admin_arn
  terraform_execution_role_arn = var.terraform_execution_role_arn
  aws_region                   = var.aws_region

  depends_on = [module.vpc]
}

# -----------------------------------------------------------------------------
# 3. Karpenter — depends on EKS for OIDC/IRSA and cluster endpoint
#    Internally manages: IAM/SQS → Helm release → NodePool + EC2NodeClass
# -----------------------------------------------------------------------------
module "karpenter" {
  source = "./modules/karpenter"

  cluster_name                        = local.cluster_name
  cluster_endpoint                    = module.eks.cluster_endpoint
  cluster_oidc_provider_arn           = module.eks.oidc_provider_arn
  karpenter_chart_version             = var.karpenter_chart_version
  karpenter_consolidate_after_seconds = var.karpenter_consolidate_after_seconds
  nodepool_cpu_limit                  = var.nodepool_cpu_limit
  node_grace_period_seconds           = var.node_grace_period_seconds
  tags                                = local.common_tags

  depends_on = [module.eks]
}

# -----------------------------------------------------------------------------
# 4. Secrets Store CSI Driver — depends on EKS (needs cluster available)
#    Installs CSI Driver + ASCP; CRDs must exist before SecretProviderClass
# -----------------------------------------------------------------------------
module "secrets_store_csi" {
  source = "./modules/secrets-store-csi"

  chart_version      = var.secrets_store_csi_chart_version
  ascp_chart_version = var.ascp_chart_version

  depends_on = [module.eks]
}

# -----------------------------------------------------------------------------
# 5. ARC Controller — depends on EKS for cluster access
#    Creates namespace and installs the controller Helm chart
# -----------------------------------------------------------------------------
module "arc_controller" {
  source = "./modules/arc-controller"

  namespace       = var.arc_namespace
  chart_version   = var.arc_controller_chart_version
  timeout_seconds = var.arc_controller_ready_timeout_seconds

  depends_on = [module.eks]
}

# -----------------------------------------------------------------------------
# 6. Secrets — KMS key, Secrets Manager secret, IRSA role for runner SA
#    Depends on EKS for OIDC provider
# -----------------------------------------------------------------------------
module "secrets" {
  source = "./modules/secrets"

  cluster_name                = local.cluster_name
  oidc_provider_arn           = module.eks.oidc_provider_arn
  oidc_provider_url           = module.eks.oidc_provider_url
  runner_namespace            = var.runner_namespace
  runner_service_account_name = "runner-sa"
  github_app_id               = var.github_app_id
  github_app_installation_id  = var.github_app_installation_id
  github_app_private_key      = local.github_app_private_key

  depends_on = [module.eks]
}

# -----------------------------------------------------------------------------
# 7. External Secrets Operator — syncs GitHub App credentials from Secrets Manager
#    into a K8s secret for ARC to consume
# -----------------------------------------------------------------------------
module "external_secrets" {
  source = "./modules/external-secrets"

  aws_region       = var.aws_region
  irsa_role_arn    = module.secrets.eso_irsa_role_arn
  runner_namespace = var.runner_namespace
  secret_name      = module.secrets.secret_name

  depends_on = [module.eks, module.secrets]
}

# -----------------------------------------------------------------------------
# 8. Runner Scale Set — depends on Karpenter (NodePool must exist for runner
#    pod scheduling), ARC controller (controller must be running to reconcile
#    the runner scale set), Secrets (IRSA role + secret ARN), and Secrets Store
#    CSI Driver (CRDs must exist before SecretProviderClass is created)
# -----------------------------------------------------------------------------
module "runner_scale_set" {
  source = "./modules/runner-scale-set"

  namespace                 = var.runner_namespace
  github_org                = var.github_org
  runner_group              = local.resolved_runner_group
  runner_labels             = var.runner_labels
  max_runners               = var.max_runners
  chart_version             = var.runner_scale_set_chart_version
  runner_cpu_request        = var.runner_cpu_request
  runner_memory_request     = var.runner_memory_request
  node_grace_period_seconds = var.node_grace_period_seconds
  secret_arn                = module.secrets.secret_arn
  irsa_role_arn             = module.secrets.irsa_role_arn

  depends_on = [module.karpenter, module.arc_controller, module.secrets, module.secrets_store_csi, module.external_secrets]
}

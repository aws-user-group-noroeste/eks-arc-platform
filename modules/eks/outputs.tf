# -----------------------------------------------------------------------------
# EKS Module - Outputs
# -----------------------------------------------------------------------------

output "cluster_name" {
  description = "The name of the EKS cluster."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "The endpoint URL of the EKS cluster API server."
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded certificate authority data for the EKS cluster."
  value       = module.eks.cluster_certificate_authority_data
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider for IRSA."
  value       = module.eks.oidc_provider_arn
}

output "oidc_provider_url" {
  description = "The OpenID Connect identity provider URL (without leading https://)."
  value       = module.eks.oidc_provider
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster control plane."
  value       = module.eks.cluster_security_group_id
}

output "node_security_group_id" {
  description = "Security group ID attached to the EKS managed node groups."
  value       = module.eks.node_security_group_id
}

output "kubeconfig_command" {
  description = "AWS CLI command to update kubeconfig for cluster access."
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "eks_managed_node_groups" {
  description = "Map of attribute maps for all EKS managed node groups created."
  value       = module.eks.eks_managed_node_groups
}

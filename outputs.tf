# -----------------------------------------------------------------------------
# Root Module - Outputs
# Requirement 3.7: Output non-empty cluster name, endpoint, and kubeconfig command.
# Requirement 6.3: Any credential-exposing output must be marked sensitive.
#                   No credential outputs are exposed at the root level by design.
# -----------------------------------------------------------------------------

output "cluster_name" {
  description = "The name of the EKS cluster."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "The endpoint URL of the EKS cluster API server."
  value       = module.eks.cluster_endpoint
}

output "kubeconfig_command" {
  description = "AWS CLI command to update kubeconfig for cluster access."
  value       = module.eks.kubeconfig_command
}

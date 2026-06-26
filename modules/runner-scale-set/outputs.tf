# -----------------------------------------------------------------------------
# Runner Scale Set Module - Outputs
# Requirements: 6.2, 6.7, 7.1, 12.3
# -----------------------------------------------------------------------------

output "namespace" {
  description = "The Kubernetes namespace where the runner scale set is installed."
  value       = kubernetes_namespace_v1.runner.metadata[0].name
}

output "service_account_name" {
  description = "The name of the IRSA-annotated ServiceAccount used by runner pods."
  value       = kubernetes_service_account_v1.runner.metadata[0].name
}

output "helm_release_name" {
  description = "The name of the runner-scale-set Helm release."
  value       = helm_release.runner_scale_set.name
}

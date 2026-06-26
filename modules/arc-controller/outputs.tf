# -----------------------------------------------------------------------------
# ARC Controller Module - Outputs
# -----------------------------------------------------------------------------

output "namespace" {
  description = "The Kubernetes namespace where the ARC controller is installed."
  value       = kubernetes_namespace_v1.arc_controller.metadata[0].name
}

output "release_name" {
  description = "The Helm release name for the ARC controller."
  value       = helm_release.arc_controller.name
}

output "chart_version" {
  description = "The installed chart version of the ARC controller."
  value       = helm_release.arc_controller.version
}

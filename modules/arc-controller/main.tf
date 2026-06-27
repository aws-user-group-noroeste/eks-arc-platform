# -----------------------------------------------------------------------------
# ARC Controller Module - Main Configuration
# Installs the GitHub Actions Runner Controller (gha-runner-scale-set-controller)
# via Helm into a dedicated namespace on the system node group.
# Requirements: 5.1, 5.2, 5.3, 5.4, 5.6
# -----------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Namespace — create if absent (Requirement 5.2)
# ---------------------------------------------------------------------------
resource "kubernetes_namespace_v1" "arc_controller" {
  metadata {
    name = var.namespace
  }

  lifecycle {
    # Don't destroy/recreate if labels or annotations drift
    ignore_changes = [
      metadata[0].labels,
      metadata[0].annotations,
    ]
  }
}

# ---------------------------------------------------------------------------
# Helm Release — gha-runner-scale-set-controller (Requirements 5.1, 5.3, 5.4, 5.6)
# ---------------------------------------------------------------------------
resource "helm_release" "arc_controller" {
  name       = "arc-controller"
  namespace  = kubernetes_namespace_v1.arc_controller.metadata[0].name
  repository = "oci://ghcr.io/actions/actions-runner-controller-charts"
  chart      = "gha-runner-scale-set-controller"
  version    = var.chart_version

  # Wait for pods to reach Ready (Requirement 5.4)
  wait    = true
  timeout = var.timeout_seconds

  # Retain created resources on failure so the Operator can retry (Requirement 5.6)
  atomic = false

  # Schedule onto system node group only and tolerate CriticalAddonsOnly taint
  # (Requirement 5.3)
  set {
    name  = "nodeSelector.workload"
    value = "system"
  }

  set {
    name  = "tolerations[0].key"
    value = "CriticalAddonsOnly"
  }

  set {
    name  = "tolerations[0].operator"
    value = "Exists"
  }

  set {
    name  = "tolerations[0].effect"
    value = "NoSchedule"
  }
}

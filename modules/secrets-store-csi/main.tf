# -----------------------------------------------------------------------------
# Secrets Store CSI Driver Module - Main Configuration
# Installs the Secrets Store CSI Driver and the AWS Secrets and Configuration
# Provider (ASCP) via Helm. Both DaemonSets tolerate the system node taint
# (CriticalAddonsOnly) and the Karpenter runner node taint (runner=true:NoSchedule)
# so that CSI volume mounts function on all nodes where runner pods may land.
# Requirements: 11.1, 11.2, 11.3, 11.4, 11.5, 11.6
# -----------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Helm Release — Secrets Store CSI Driver (Requirements 11.1, 11.3, 11.4, 11.5)
# ---------------------------------------------------------------------------
resource "helm_release" "secrets_store_csi_driver" {
  name       = "secrets-store-csi-driver"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
  chart      = "secrets-store-csi-driver"
  version    = var.chart_version

  # Wait for DaemonSet pods to reach Ready (Requirement 11.5)
  wait    = true
  timeout = 300

  # Retain created resources on failure so the Operator can retry (Requirement 11.5)
  atomic = false

  # Enable syncing of Secrets Manager secrets to Kubernetes Secrets (Requirement 11.3)
  set {
    name  = "syncSecret.enabled"
    value = "true"
  }

  # Enable secret rotation so out-of-band updates propagate (Requirement 6.6)
  set {
    name  = "enableSecretRotation"
    value = "true"
  }

  # Poll interval for secret rotation
  set {
    name  = "rotationPollInterval"
    value = "120s"
  }

  # DaemonSet tolerations: system nodes (CriticalAddonsOnly) + Karpenter runner
  # nodes (runner=true:NoSchedule) so the driver runs on ALL nodes (Requirement 11.4)
  set {
    name  = "linux.tolerations[0].key"
    value = "CriticalAddonsOnly"
  }

  set {
    name  = "linux.tolerations[0].operator"
    value = "Exists"
  }

  set {
    name  = "linux.tolerations[0].effect"
    value = "NoSchedule"
  }

  set {
    name  = "linux.tolerations[1].key"
    value = "runner"
  }

  set {
    name  = "linux.tolerations[1].operator"
    value = "Equal"
  }

  set {
    name  = "linux.tolerations[1].value"
    type  = "string"
    value = "true"
  }

  set {
    name  = "linux.tolerations[1].effect"
    value = "NoSchedule"
  }
}

# ---------------------------------------------------------------------------
# Helm Release — AWS Secrets and Configuration Provider (Requirements 11.2, 11.4, 11.5)
# ---------------------------------------------------------------------------
resource "helm_release" "ascp" {
  name       = "secrets-store-csi-driver-provider-aws"
  namespace  = "kube-system"
  repository = "https://aws.github.io/secrets-store-csi-driver-provider-aws"
  chart      = "secrets-store-csi-driver-provider-aws"
  version    = var.ascp_chart_version

  # Wait for DaemonSet pods to reach Ready (Requirement 11.5)
  wait    = true
  timeout = 300

  # Retain created resources on failure so the Operator can retry (Requirement 11.5)
  atomic = false

  # DaemonSet tolerations: system nodes (CriticalAddonsOnly) + Karpenter runner
  # nodes (runner=true:NoSchedule) so the provider runs on ALL nodes (Requirement 11.4)
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

  set {
    name  = "tolerations[1].key"
    value = "runner"
  }

  set {
    name  = "tolerations[1].operator"
    value = "Equal"
  }

  set {
    name  = "tolerations[1].value"
    type  = "string"
    value = "true"
  }

  set {
    name  = "tolerations[1].effect"
    value = "NoSchedule"
  }

  # Ensure the CSI Driver CRDs are available before installing the provider
  depends_on = [helm_release.secrets_store_csi_driver]
}

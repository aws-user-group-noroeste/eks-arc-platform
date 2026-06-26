# -----------------------------------------------------------------------------
# Runner Scale Set Module - Main Configuration
# Creates the SecretProviderClass (CSI-driven secret sync), an IRSA-annotated
# ServiceAccount, and the gha-runner-scale-set Helm release with CSI volume
# mount for secret access.
# Requirements: 6.2, 6.6, 6.7, 7.1, 7.2, 7.3, 7.4, 7.6, 7.7, 7.8,
#               8.1, 8.2, 8.3, 8.4, 8.5, 12.3
# -----------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Namespace — create the runner namespace (Requirement 6.2)
# ---------------------------------------------------------------------------
resource "kubernetes_namespace_v1" "runner" {
  metadata {
    name = var.namespace
  }

  lifecycle {
    ignore_changes = [
      metadata[0].labels,
      metadata[0].annotations,
    ]
  }
}

# ---------------------------------------------------------------------------
# Service Account — annotated with IRSA role ARN so runner pods receive
# AWS credentials to access Secrets Manager (Requirement 12.3)
# ---------------------------------------------------------------------------
resource "kubernetes_service_account_v1" "runner" {
  metadata {
    name      = "runner-sa"
    namespace = kubernetes_namespace_v1.runner.metadata[0].name

    annotations = {
      "eks.amazonaws.com/role-arn" = var.irsa_role_arn
    }
  }

  automount_service_account_token = true
}

# ---------------------------------------------------------------------------
# NOTE: GitHub App credentials are delivered to the runner namespace as the
# "github-app-secret" Kubernetes secret by the External Secrets Operator
# (see module.external_secrets), which syncs from AWS Secrets Manager. The
# previous Secrets Store CSI SecretProviderClass approach is no longer needed.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Helm Release — gha-runner-scale-set
# (Requirements 7.1, 7.2, 7.3, 7.4, 7.6, 7.7, 7.8, 8.1, 8.2, 8.3, 8.4, 8.5)
#
# Installs the runner scale set registered at the GitHub org level, with
# scale-to-zero, Docker-in-Docker container mode, scheduling onto Karpenter
# runner nodes, ephemeral one-job runner mode, CSI volume mount for secret
# sync, and Operator-configurable resource requests.
# ---------------------------------------------------------------------------
resource "helm_release" "runner_scale_set" {
  name       = "arc-runner-set"
  namespace  = kubernetes_namespace_v1.runner.metadata[0].name
  repository = "oci://ghcr.io/actions/actions-runner-controller-charts"
  chart      = "gha-runner-scale-set"
  version    = var.chart_version

  # Wait for the release to complete but do not roll back on failure
  # so already-created resources are retained for retry.
  wait   = true
  atomic = false

  # --- GitHub registration (Requirement 7.1) ---
  set {
    name  = "githubConfigUrl"
    value = "https://github.com/${var.github_org}"
  }

  set {
    name  = "githubConfigSecret"
    value = "github-app-secret"
  }

  # --- Scaling (Requirements 7.3, 7.4) ---
  set {
    name  = "minRunners"
    value = "0"
  }

  set {
    name  = "maxRunners"
    value = tostring(var.max_runners)
  }

  # --- Runner group (Requirement 7.2) ---
  set {
    name  = "runnerGroup"
    value = var.runner_group
  }

  # --- Runner labels for job targeting (Requirement 7.2) ---
  dynamic "set" {
    for_each = var.runner_labels
    content {
      name  = "labels[${set.key}]"
      value = set.value
    }
  }

  # --- Container mode: Docker-in-Docker for isolation (Requirement 8.4) ---
  set {
    name  = "containerMode.type"
    value = "dind"
  }

  # --- Pod template: serviceAccountName (Requirement 12.3) ---
  set {
    name  = "template.spec.serviceAccountName"
    value = kubernetes_service_account_v1.runner.metadata[0].name
  }

  # --- Pod template: resource requests (Requirement 8.1) ---
  set {
    name  = "template.spec.containers[0].name"
    value = "runner"
  }

  # The runner container image. Required because we customize containers[0];
  # ARC's default runner image, pinned via var for reproducibility.
  set {
    name  = "template.spec.containers[0].image"
    value = var.runner_image
  }

  set {
    name  = "template.spec.containers[0].command[0]"
    value = "/home/runner/run.sh"
  }

  set {
    name  = "template.spec.containers[0].resources.requests.cpu"
    value = var.runner_cpu_request
  }

  set {
    name  = "template.spec.containers[0].resources.requests.memory"
    value = var.runner_memory_request
  }

  # --- Pod template: nodeSelector for Karpenter nodes (Requirement 8.2) ---
  set {
    name  = "template.spec.nodeSelector.workload"
    value = "runner"
  }

  # --- Pod template: toleration for runner=true:NoSchedule (Requirement 8.2) ---
  set {
    name  = "template.spec.tolerations[0].key"
    value = "runner"
  }

  set {
    name  = "template.spec.tolerations[0].value"
    type  = "string"
    value = "true"
  }

  set {
    name  = "template.spec.tolerations[0].effect"
    value = "NoSchedule"
  }

  # --- Pod template: terminationGracePeriodSeconds (Requirement 7.9) ---
  set {
    name  = "template.spec.terminationGracePeriodSeconds"
    value = tostring(var.node_grace_period_seconds)
  }

  # --- Listener pod: schedule on system nodes (tolerate CriticalAddonsOnly) ---
  # The listener runs in the controller namespace and must land on a system node.
  set {
    name  = "listenerTemplate.spec.nodeSelector.workload"
    value = "system"
  }

  set {
    name  = "listenerTemplate.spec.tolerations[0].key"
    value = "CriticalAddonsOnly"
  }

  set {
    name  = "listenerTemplate.spec.tolerations[0].operator"
    value = "Exists"
  }

  set {
    name  = "listenerTemplate.spec.tolerations[0].effect"
    value = "NoSchedule"
  }

  # listenerTemplate requires a container entry named "listener"
  set {
    name  = "listenerTemplate.spec.containers[0].name"
    value = "listener"
  }

  depends_on = [
    kubernetes_service_account_v1.runner,
  ]
}

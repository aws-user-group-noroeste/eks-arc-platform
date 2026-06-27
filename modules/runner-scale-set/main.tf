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

  set = concat(
    [
      # --- GitHub registration (Requirement 7.1) ---
      {
        name  = "githubConfigUrl"
        value = "https://github.com/${var.github_org}"
      },
      {
        name  = "githubConfigSecret"
        value = "github-app-secret"
      },
      # --- Scaling (Requirements 7.3, 7.4) ---
      {
        name  = "minRunners"
        value = "0"
      },
      {
        name  = "maxRunners"
        value = tostring(var.max_runners)
      },
      # --- Runner group (Requirement 7.2) ---
      {
        name  = "runnerGroup"
        value = var.runner_group
      },
      # --- Container mode: Docker-in-Docker for isolation (Requirement 8.4) ---
      {
        name  = "containerMode.type"
        value = "dind"
      },
      # --- Pod template: serviceAccountName (Requirement 12.3) ---
      {
        name  = "template.spec.serviceAccountName"
        value = kubernetes_service_account_v1.runner.metadata[0].name
      },
      # --- Pod template: runner container (name + image required when customized) ---
      {
        name  = "template.spec.containers[0].name"
        value = "runner"
      },
      {
        name  = "template.spec.containers[0].image"
        value = var.runner_image
      },
      {
        name  = "template.spec.containers[0].command[0]"
        value = "/home/runner/run.sh"
      },
      # --- Pod template: resource requests (Requirement 8.1) ---
      {
        name  = "template.spec.containers[0].resources.requests.cpu"
        value = var.runner_cpu_request
      },
      {
        name  = "template.spec.containers[0].resources.requests.memory"
        value = var.runner_memory_request
      },
      # --- Pod template: nodeSelector for Karpenter nodes (Requirement 8.2) ---
      {
        name  = "template.spec.nodeSelector.workload"
        value = "runner"
      },
      # --- Pod template: toleration for runner=true:NoSchedule (Requirement 8.2) ---
      {
        name  = "template.spec.tolerations[0].key"
        value = "runner"
      },
      {
        name  = "template.spec.tolerations[0].value"
        type  = "string"
        value = "true"
      },
      {
        name  = "template.spec.tolerations[0].effect"
        value = "NoSchedule"
      },
      # --- Pod template: terminationGracePeriodSeconds (Requirement 7.9) ---
      {
        name  = "template.spec.terminationGracePeriodSeconds"
        value = tostring(var.node_grace_period_seconds)
      },
      # --- Listener pod: schedule on system nodes (tolerate CriticalAddonsOnly) ---
      {
        name  = "listenerTemplate.spec.nodeSelector.workload"
        value = "system"
      },
      {
        name  = "listenerTemplate.spec.tolerations[0].key"
        value = "CriticalAddonsOnly"
      },
      {
        name  = "listenerTemplate.spec.tolerations[0].operator"
        value = "Exists"
      },
      {
        name  = "listenerTemplate.spec.tolerations[0].effect"
        value = "NoSchedule"
      },
      {
        name  = "listenerTemplate.spec.containers[0].name"
        value = "listener"
      },
    ],
    # --- Runner labels for job targeting (Requirement 7.2) ---
    [
      for i, label in var.runner_labels : {
        name  = "labels[${i}]"
        value = label
      }
    ],
  )

  depends_on = [
    kubernetes_service_account_v1.runner,
  ]
}

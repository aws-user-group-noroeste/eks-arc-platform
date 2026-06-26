# -----------------------------------------------------------------------------
# External Secrets Operator Module
# Installs ESO via Helm and creates a ClusterSecretStore + ExternalSecret
# to sync GitHub App credentials from AWS Secrets Manager into K8s.
# -----------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Helm Release — External Secrets Operator
# ---------------------------------------------------------------------------
resource "helm_release" "external_secrets" {
  name       = "external-secrets"
  namespace  = "kube-system"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = var.chart_version

  wait    = true
  timeout = 300
  atomic  = false

  set {
    name  = "installCRDs"
    value = "true"
  }

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

  set {
    name  = "webhook.nodeSelector.workload"
    value = "system"
  }

  set {
    name  = "webhook.tolerations[0].key"
    value = "CriticalAddonsOnly"
  }

  set {
    name  = "webhook.tolerations[0].operator"
    value = "Exists"
  }

  set {
    name  = "webhook.tolerations[0].effect"
    value = "NoSchedule"
  }

  set {
    name  = "certController.nodeSelector.workload"
    value = "system"
  }

  set {
    name  = "certController.tolerations[0].key"
    value = "CriticalAddonsOnly"
  }

  set {
    name  = "certController.tolerations[0].operator"
    value = "Exists"
  }

  set {
    name  = "certController.tolerations[0].effect"
    value = "NoSchedule"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = var.irsa_role_arn
  }
}

# ---------------------------------------------------------------------------
# ClusterSecretStore + ExternalSecret — deployed via a local Helm chart
# (authored in-repo) so the official helm provider defers CR creation to
# apply-time, avoiding the kubernetes_manifest plan-time CRD limitation.
# ---------------------------------------------------------------------------
resource "helm_release" "eso_resources" {
  name      = "eso-resources"
  namespace = "kube-system"
  chart     = "${path.module}/charts/eso-resources"

  wait    = true
  timeout = 300
  atomic  = false

  set {
    name  = "awsRegion"
    value = var.aws_region
  }

  set {
    name  = "runnerNamespace"
    value = var.runner_namespace
  }

  set {
    name  = "secretName"
    value = var.secret_name
  }

  depends_on = [helm_release.external_secrets]
}

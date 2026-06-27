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

  set = [
    {
      name  = "installCRDs"
      value = "true"
    },
    {
      name  = "nodeSelector.workload"
      value = "system"
    },
    {
      name  = "tolerations[0].key"
      value = "CriticalAddonsOnly"
    },
    {
      name  = "tolerations[0].operator"
      value = "Exists"
    },
    {
      name  = "tolerations[0].effect"
      value = "NoSchedule"
    },
    {
      name  = "webhook.nodeSelector.workload"
      value = "system"
    },
    {
      name  = "webhook.tolerations[0].key"
      value = "CriticalAddonsOnly"
    },
    {
      name  = "webhook.tolerations[0].operator"
      value = "Exists"
    },
    {
      name  = "webhook.tolerations[0].effect"
      value = "NoSchedule"
    },
    {
      name  = "certController.nodeSelector.workload"
      value = "system"
    },
    {
      name  = "certController.tolerations[0].key"
      value = "CriticalAddonsOnly"
    },
    {
      name  = "certController.tolerations[0].operator"
      value = "Exists"
    },
    {
      name  = "certController.tolerations[0].effect"
      value = "NoSchedule"
    },
    {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = var.irsa_role_arn
    },
  ]
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

  set = [
    {
      name  = "awsRegion"
      value = var.aws_region
    },
    {
      name  = "runnerNamespace"
      value = var.runner_namespace
    },
    {
      name  = "secretName"
      value = var.secret_name
    },
  ]

  depends_on = [helm_release.external_secrets]
}

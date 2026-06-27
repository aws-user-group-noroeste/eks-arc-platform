# -----------------------------------------------------------------------------
# Karpenter Module - AWS Prerequisites (Layer 1)
# Creates controller IAM role, node IAM role + instance profile, and
# SQS interruption queue with EventBridge rules via the EKS module's
# karpenter submodule (v21). v21 uses Pod Identity + v1 permissions by default.
# Requirements: 4.2
# -----------------------------------------------------------------------------

module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 21.0"

  cluster_name = var.cluster_name

  # Create the node IAM role and instance profile for Karpenter-launched nodes
  create_node_iam_role    = true
  node_iam_role_name      = var.node_iam_role_name
  create_instance_profile = true

  # Enable SQS-based spot termination handling (EventBridge rules + queue)
  enable_spot_termination = true

  # Pod Identity for the Karpenter controller (default in v21; requires the
  # eks-pod-identity-agent addon). v1 controller permissions are the default.
  create_pod_identity_association = true
  namespace                       = "kube-system"
  service_account                 = "karpenter"

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Supplementary IAM policy for the Karpenter controller role.
# Karpenter 1.13 calls iam:ListInstanceProfiles during EC2NodeClass
# reconciliation; granted here defensively in case the module's v1 policy
# does not include it. Without it the EC2NodeClass can stay "not ready".
# -----------------------------------------------------------------------------
resource "aws_iam_role_policy" "karpenter_controller_extra" {
  name = "ListInstanceProfiles"
  role = module.karpenter.iam_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ListInstanceProfiles"
        Effect   = "Allow"
        Action   = ["iam:ListInstanceProfiles"]
        Resource = "*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Karpenter Module - Helm Release (Layer 2)
# Installs Karpenter into kube-system, pinned to karpenter_chart_version.
# Requirements: 4.1, 4.3, 4.5, 9.3, 9.4
# -----------------------------------------------------------------------------

resource "helm_release" "karpenter" {
  name       = "karpenter"
  namespace  = "kube-system"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = var.karpenter_chart_version

  # Wait for controller pods to be ready before applying CRD-dependent manifests
  wait    = true
  timeout = 600
  atomic  = false

  # Schedule onto system node group only and tolerate CriticalAddonsOnly taint
  set = [
    {
      name  = "settings.clusterName"
      value = var.cluster_name
    },
    {
      name  = "settings.clusterEndpoint"
      value = var.cluster_endpoint
    },
    {
      name  = "settings.interruptionQueue"
      value = module.karpenter.queue_name
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
  ]
}

# -----------------------------------------------------------------------------
# Karpenter Module - NodePool + EC2NodeClass (Layer 2)
# Deployed via a local Helm chart (authored in-repo) using the official helm
# provider. Helm defers CR creation to apply-time, avoiding the plan-time CRD
# validation limitation of the kubernetes_manifest resource.
# Requirements: 4.3-4.8, 7.10, 7.11, 9.1-9.5
# -----------------------------------------------------------------------------

resource "helm_release" "karpenter_resources" {
  name      = "karpenter-resources"
  namespace = "kube-system"
  chart     = "${path.module}/charts/karpenter-resources"

  wait    = true
  timeout = 300
  atomic  = false

  set = [
    {
      name  = "clusterName"
      value = var.cluster_name
    },
    {
      name  = "nodeIamRoleName"
      value = module.karpenter.node_iam_role_name
    },
    {
      name  = "cpuLimit"
      value = tostring(var.nodepool_cpu_limit)
    },
    {
      name  = "consolidateAfterSeconds"
      value = tostring(var.karpenter_consolidate_after_seconds)
    },
    {
      name  = "nodeGracePeriodSeconds"
      value = tostring(var.node_grace_period_seconds)
    },
  ]

  depends_on = [helm_release.karpenter]
}

# -----------------------------------------------------------------------------
# Karpenter Module - AWS Prerequisites (Layer 1)
# Creates controller IAM role, node IAM role + instance profile, and
# SQS interruption queue with EventBridge rules via the EKS module's
# karpenter submodule.
# Requirements: 4.2
# -----------------------------------------------------------------------------

module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 20.31"

  cluster_name = var.cluster_name

  # Create the node IAM role and instance profile for Karpenter-launched nodes
  create_node_iam_role    = true
  node_iam_role_name      = var.node_iam_role_name
  create_instance_profile = true

  # Enable SQS-based spot termination handling (EventBridge rules + queue)
  enable_spot_termination = true

  # Use Pod Identity for the Karpenter controller (requires eks-pod-identity-agent addon)
  create_pod_identity_association = true
  enable_v1_permissions           = true
  namespace                       = "kube-system"
  service_account                 = "karpenter"

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Supplementary IAM policy for the Karpenter controller role.
# Karpenter 1.13 calls iam:ListInstanceProfiles during EC2NodeClass
# reconciliation, which the EKS module v20.31 v1 policy does not grant.
# Without it the EC2NodeClass stays "not ready" and no nodes are provisioned.
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

  # Retain created resources on failure so the Operator can retry
  atomic = false

  # Schedule onto system node group only and tolerate CriticalAddonsOnly taint
  set {
    name  = "settings.clusterName"
    value = var.cluster_name
  }

  set {
    name  = "settings.clusterEndpoint"
    value = var.cluster_endpoint
  }

  set {
    name  = "settings.interruptionQueue"
    value = module.karpenter.queue_name
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

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "nodeIamRoleName"
    value = module.karpenter.node_iam_role_name
  }

  set {
    name  = "cpuLimit"
    value = tostring(var.nodepool_cpu_limit)
  }

  set {
    name  = "consolidateAfterSeconds"
    value = tostring(var.karpenter_consolidate_after_seconds)
  }

  set {
    name  = "nodeGracePeriodSeconds"
    value = tostring(var.node_grace_period_seconds)
  }

  depends_on = [helm_release.karpenter]
}

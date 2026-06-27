# -----------------------------------------------------------------------------
# Karpenter Module - Input Variables
# Layer 1: AWS prerequisites (IAM, instance profile, SQS queue)
# Layer 2: Helm release + NodePool/EC2NodeClass (task 6.2)
# -----------------------------------------------------------------------------

variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
}

variable "cluster_endpoint" {
  description = "Endpoint URL of the EKS cluster API server (used for IRSA trust)."
  type        = string
}

variable "cluster_oidc_provider_arn" {
  description = "ARN of the OIDC provider for IRSA, from the EKS module."
  type        = string
}

variable "node_iam_role_name" {
  description = "Optional name for the Karpenter node IAM role. Derived from cluster_name if not set."
  type        = string
  default     = null
}

variable "tags" {
  description = "A map of tags to add to all resources."
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# Layer 2: Helm release + NodePool/EC2NodeClass
# -----------------------------------------------------------------------------

variable "karpenter_chart_version" {
  description = "Exact pinned semver version of the Karpenter Helm chart (e.g. 1.0.6)."
  type        = string
}

variable "karpenter_consolidate_after_seconds" {
  description = "Seconds an empty/underutilized node is retained before Karpenter terminates it (0–3600)."
  type        = number
  default     = 30
}

variable "nodepool_cpu_limit" {
  description = "Maximum total CPU cores Karpenter may provision for runner nodes (1–10000)."
  type        = number
  default     = 100
}

variable "node_grace_period_seconds" {
  description = "Seconds an emptied runner node is retained so rapidly re-queued jobs can reuse it (0–3600)."
  type        = number
  default     = 300
}

# -----------------------------------------------------------------------------
# Karpenter Module - Outputs (Layer 1: AWS Prerequisites)
# Exposes the node IAM role name, queue name, and controller role ARN
# for the Helm/NodeClass layer (task 6.2).
# -----------------------------------------------------------------------------

output "karpenter_node_iam_role_name" {
  description = "Name of the Karpenter node IAM role, used in the EC2NodeClass spec."
  value       = module.karpenter.node_iam_role_name
}

output "karpenter_queue_name" {
  description = "Name of the SQS interruption queue for Karpenter Helm chart settings."
  value       = module.karpenter.queue_name
}

output "karpenter_irsa_role_arn" {
  description = "ARN of the Karpenter controller IAM role for service account annotation."
  value       = module.karpenter.iam_role_arn
}

output "karpenter_instance_profile_name" {
  description = "Name of the IAM instance profile for Karpenter-launched nodes."
  value       = module.karpenter.instance_profile_name
}

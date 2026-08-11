# -----------------------------------------------------------------------------
# EKS Module - Input Variables
# -----------------------------------------------------------------------------

variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes minor version for the EKS control plane."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC in which to create the EKS cluster."
  type        = string
}

variable "subnet_ids" {
  description = "List of private subnet IDs for EKS cluster and node groups."
  type        = list(string)
}

variable "system_node_group_max_size" {
  description = "Maximum number of nodes in the system managed node group."
  type        = number
  default     = 3
}

variable "aws_region" {
  description = "AWS region for the kubeconfig command."
  type        = string
}

variable "cluster_admin_arn" {
  description = "IAM principal ARN to grant EKS cluster admin access (for kubectl)."
  type        = string
}

variable "terraform_execution_role_arn" {
  description = "ARN of the Terraform execution role (needs K8s API access for Helm/manifest resources)."
  type        = string
}

variable "enable_ipv6" {
  description = "Set EKS cluster ip_family to ipv6. Must match the VPC's enable_ipv6 setting. Cannot be changed after cluster creation."
  type        = bool
  default     = false
}

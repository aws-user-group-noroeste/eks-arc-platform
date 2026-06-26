# -----------------------------------------------------------------------------
# Secrets Module - Input Variables
# Manages KMS key, Secrets Manager secret, and IRSA role for GitHub App
# credentials access.
# Requirements: 6.1, 6.2, 6.3, 12.1, 12.2, 12.3, 12.4, 12.5, 12.6, 13.1,
#               13.2, 13.4, 13.5, 13.7
# -----------------------------------------------------------------------------

variable "cluster_name" {
  description = "Name of the EKS cluster, used for resource naming."
  type        = string
}

variable "runner_namespace" {
  description = "Kubernetes namespace where the Runner Scale Set is deployed."
  type        = string
}

variable "runner_service_account_name" {
  description = "Name of the Kubernetes service account used by the runner pods."
  type        = string
  default     = "arc-runner"
}

variable "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider for IRSA trust policy."
  type        = string
}

variable "oidc_provider_url" {
  description = "EKS OIDC provider URL without the https:// prefix."
  type        = string
}

variable "github_app_id" {
  description = "GitHub App ID (numeric string)."
  type        = string
  sensitive   = true
}

variable "github_app_installation_id" {
  description = "GitHub App Installation ID (numeric string)."
  type        = string
  sensitive   = true
}

variable "github_app_private_key" {
  description = "GitHub App private key in PEM format."
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "A map of tags to add to all resources."
  type        = map(string)
  default     = {}
}

variable "eso_namespace" {
  description = "Namespace where External Secrets Operator runs."
  type        = string
  default     = "kube-system"
}

variable "eso_service_account_name" {
  description = "Service account name used by External Secrets Operator."
  type        = string
  default     = "external-secrets"
}

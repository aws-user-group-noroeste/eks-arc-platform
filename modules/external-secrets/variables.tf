# -----------------------------------------------------------------------------
# External Secrets Module - Variables
# -----------------------------------------------------------------------------

variable "chart_version" {
  description = "Helm chart version for external-secrets operator."
  type        = string
  default     = "0.17.0"
}

variable "aws_region" {
  description = "AWS region for Secrets Manager."
  type        = string
}

variable "irsa_role_arn" {
  description = "IAM role ARN for ESO service account (IRSA) to access Secrets Manager."
  type        = string
}

variable "runner_namespace" {
  description = "Namespace where the ExternalSecret and target K8s secret will be created."
  type        = string
}

variable "secret_name" {
  description = "Name of the secret in AWS Secrets Manager."
  type        = string
}

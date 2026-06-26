# -----------------------------------------------------------------------------
# Runner Scale Set Module - Input Variables
# Declares all inputs needed for the SecretProviderClass, IRSA-annotated
# ServiceAccount, and the gha-runner-scale-set Helm release.
# Requirements: 6.2, 6.6, 6.7, 7.1, 7.2, 7.3, 7.4, 7.6, 7.7, 7.8,
#               8.1, 8.2, 8.3, 8.4, 8.5, 12.3
# -----------------------------------------------------------------------------

variable "namespace" {
  description = "Kubernetes namespace for the runner scale set and SecretProviderClass."
  type        = string
  default     = "arc-runners"
}

variable "chart_version" {
  description = "Exact pinned semver version of the gha-runner-scale-set Helm chart."
  type        = string
}

variable "github_org" {
  description = "GitHub organization name for runner registration."
  type        = string
}

variable "runner_group" {
  description = "GitHub runner group to register the scale set in."
  type        = string
  default     = "default"
}

variable "runner_labels" {
  description = "Labels to assign to the runner scale set. Must contain at least one label."
  type        = list(string)
}

variable "max_runners" {
  description = "Maximum number of runner replicas (1–1000)."
  type        = number
  default     = 10
}

variable "runner_cpu_request" {
  description = "Kubernetes CPU resource request for runner pods."
  type        = string
  default     = "1"
}

variable "runner_memory_request" {
  description = "Kubernetes memory resource request for runner pods."
  type        = string
  default     = "2Gi"
}

variable "node_grace_period_seconds" {
  description = "Termination grace period in seconds for runner pods (0–3600)."
  type        = number
  default     = 300
}

variable "secret_arn" {
  description = "ARN of the Secrets Manager secret containing GitHub App credentials."
  type        = string
}

variable "irsa_role_arn" {
  description = "ARN of the IRSA IAM role for runner pods to access Secrets Manager."
  type        = string
}

variable "runner_image" {
  description = "Container image for the runner pod. Pin to a specific tag for reproducibility."
  type        = string
  default     = "ghcr.io/actions/actions-runner:latest"
}

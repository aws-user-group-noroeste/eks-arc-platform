# -----------------------------------------------------------------------------
# ARC Controller Module - Input Variables
# -----------------------------------------------------------------------------

variable "namespace" {
  description = "Kubernetes namespace for the ARC controller (created if absent)."
  type        = string
  default     = "arc-systems"
}

variable "chart_version" {
  description = "Exact pinned semver version of the gha-runner-scale-set-controller Helm chart."
  type        = string
}

variable "timeout_seconds" {
  description = "Seconds to wait for the ARC controller pods to reach Ready status."
  type        = number
  default     = 300
}

# -----------------------------------------------------------------------------
# Secrets Store CSI Driver Module - Input Variables
# -----------------------------------------------------------------------------

variable "chart_version" {
  description = "Exact pinned semver version of the Secrets Store CSI Driver Helm chart."
  type        = string
}

variable "ascp_chart_version" {
  description = "Exact pinned semver version of the AWS Secrets and Configuration Provider (ASCP) Helm chart."
  type        = string
}

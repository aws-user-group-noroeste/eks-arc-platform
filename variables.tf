# -----------------------------------------------------------------------------
# Input Variables
# -----------------------------------------------------------------------------

variable "terraform_execution_role_arn" {
  description = "ARN of the IAM role Terraform assumes for provisioning. Created by the s3-backend module."
  type        = string

  validation {
    condition     = can(regex("^arn:aws:iam::\\d{12}:role/.+$", var.terraform_execution_role_arn))
    error_message = "terraform_execution_role_arn must be a valid IAM role ARN (arn:aws:iam::<account>:role/<name>)."
  }
}

variable "cluster_admin_arn" {
  description = "IAM principal ARN granted EKS cluster admin access for kubectl operations."
  type        = string

  validation {
    condition     = can(regex("^arn:aws:iam::\\d{12}:(role|user)/.+$", var.cluster_admin_arn))
    error_message = "cluster_admin_arn must be a valid IAM role or user ARN."
  }
}

variable "aws_region" {
  description = "AWS region in which to provision all resources."
  type        = string
  default     = "us-east-1"

  validation {
    condition     = length(var.aws_region) > 0
    error_message = "aws_region must not be empty."
  }
}

variable "state_key" {
  description = "S3 state object key path (1–1024 characters). Supplied via backend config but validated here for documentation."
  type        = string
  default     = "terraform/eks-arc-runners/terraform.tfstate"

  validation {
    condition     = length(var.state_key) >= 1 && length(var.state_key) <= 1024
    error_message = "state_key must be between 1 and 1024 characters."
  }
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block for the new VPC."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "nat_gateway_count" {
  description = "Number of NAT gateways to provision (one per AZ for HA, or 1 for cost savings)."
  type        = number
  default     = 1

  validation {
    condition     = var.nat_gateway_count >= 1 && var.nat_gateway_count == floor(var.nat_gateway_count)
    error_message = "nat_gateway_count must be an integer greater than or equal to 1."
  }
}

variable "kubernetes_version" {
  description = "EKS Kubernetes minor version."
  type        = string
  default     = "1.36"

  validation {
    condition     = contains(["1.30", "1.31", "1.32", "1.33", "1.34", "1.35", "1.36"], var.kubernetes_version)
    error_message = "kubernetes_version must be a supported EKS version (one of: 1.30, 1.31, 1.32, 1.33, 1.34, 1.35, 1.36)."
  }
}

variable "system_node_group_max_size" {
  description = "Maximum number of nodes in the system managed node group."
  type        = number
  default     = 3

  validation {
    condition     = var.system_node_group_max_size >= 1 && var.system_node_group_max_size == floor(var.system_node_group_max_size)
    error_message = "system_node_group_max_size must be an integer greater than or equal to 1."
  }
}

variable "karpenter_chart_version" {
  description = "Exact semver version of the Karpenter Helm chart (e.g. 1.0.6)."
  type        = string
  default     = "1.0.6"

  validation {
    condition     = can(regex("^\\d+\\.\\d+\\.\\d+$", var.karpenter_chart_version))
    error_message = "karpenter_chart_version must be an exact semantic version (e.g. '1.0.6'). Ranges, wildcards, and floating tags are not allowed."
  }
}

variable "karpenter_consolidate_after_seconds" {
  description = "Seconds a Karpenter node must be empty before consolidation (0–3600)."
  type        = number
  default     = 30

  validation {
    condition     = var.karpenter_consolidate_after_seconds >= 0 && var.karpenter_consolidate_after_seconds <= 3600 && var.karpenter_consolidate_after_seconds == floor(var.karpenter_consolidate_after_seconds)
    error_message = "karpenter_consolidate_after_seconds must be an integer between 0 and 3600 inclusive."
  }
}

variable "nodepool_cpu_limit" {
  description = "Maximum total CPU cores the Karpenter NodePool may provision (1–10000)."
  type        = number
  default     = 100

  validation {
    condition     = var.nodepool_cpu_limit >= 1 && var.nodepool_cpu_limit <= 10000 && var.nodepool_cpu_limit == floor(var.nodepool_cpu_limit)
    error_message = "nodepool_cpu_limit must be an integer between 1 and 10000 inclusive."
  }
}

variable "arc_controller_chart_version" {
  description = "Exact semver version of the ARC controller Helm chart (e.g. 0.9.3)."
  type        = string

  validation {
    condition     = can(regex("^\\d+\\.\\d+\\.\\d+$", var.arc_controller_chart_version))
    error_message = "arc_controller_chart_version must be an exact semantic version (e.g. '0.9.3'). Ranges, wildcards, and floating tags are not allowed."
  }
}

variable "arc_namespace" {
  description = "Kubernetes namespace for the ARC controller (RFC1123 label, max 63 chars)."
  type        = string
  default     = "arc-systems"

  validation {
    condition     = can(regex("^[a-z]([a-z0-9-]{0,61}[a-z0-9])?$", var.arc_namespace))
    error_message = "arc_namespace must be a valid RFC1123 label (lowercase alphanumeric and hyphens, starts with a letter, ends with alphanumeric, max 63 characters)."
  }
}

variable "arc_controller_ready_timeout_seconds" {
  description = "Seconds to wait for ARC controller pods to become Ready."
  type        = number
  default     = 300

  validation {
    condition     = var.arc_controller_ready_timeout_seconds > 0 && var.arc_controller_ready_timeout_seconds == floor(var.arc_controller_ready_timeout_seconds)
    error_message = "arc_controller_ready_timeout_seconds must be a positive integer (> 0)."
  }
}

variable "runner_scale_set_chart_version" {
  description = "Exact semver version of the ARC runner-scale-set Helm chart (e.g. 0.9.3)."
  type        = string

  validation {
    condition     = can(regex("^\\d+\\.\\d+\\.\\d+$", var.runner_scale_set_chart_version))
    error_message = "runner_scale_set_chart_version must be an exact semantic version (e.g. '0.9.3'). Ranges, wildcards, and floating tags are not allowed."
  }
}

variable "runner_namespace" {
  description = "Kubernetes namespace for the runner scale set (RFC1123 label, max 63 chars)."
  type        = string
  default     = "arc-runners"

  validation {
    condition     = can(regex("^[a-z]([a-z0-9-]{0,61}[a-z0-9])?$", var.runner_namespace))
    error_message = "runner_namespace must be a valid RFC1123 label (lowercase alphanumeric and hyphens, starts with a letter, ends with alphanumeric, max 63 characters)."
  }
}

variable "github_org" {
  description = "GitHub organization name where runners will be registered."
  type        = string

  validation {
    condition     = length(var.github_org) > 0
    error_message = "github_org must not be empty."
  }
}

variable "runner_group" {
  description = "GitHub runner group name."
  type        = string
  default     = "default"

  validation {
    condition     = length(var.runner_group) > 0
    error_message = "runner_group must not be empty."
  }
}

variable "runner_labels" {
  description = "List of labels to apply to the runner scale set. Must contain at least one label."
  type        = list(string)

  validation {
    condition     = length(var.runner_labels) >= 1
    error_message = "runner_labels must contain at least one label."
  }
}

variable "max_runners" {
  description = "Maximum number of concurrent runner replicas (1–1000)."
  type        = number
  default     = 10

  validation {
    condition     = var.max_runners >= 1 && var.max_runners <= 1000 && var.max_runners == floor(var.max_runners)
    error_message = "max_runners must be an integer between 1 and 1000 inclusive."
  }
}

variable "node_grace_period_seconds" {
  description = "Seconds to retain an emptied runner node before termination (0–3600)."
  type        = number
  default     = 300

  validation {
    condition     = var.node_grace_period_seconds >= 0 && var.node_grace_period_seconds <= 3600 && var.node_grace_period_seconds == floor(var.node_grace_period_seconds)
    error_message = "node_grace_period_seconds must be an integer between 0 and 3600 inclusive."
  }
}

variable "runner_cpu_request" {
  description = "CPU resource request for runner pods (Kubernetes quantity, e.g. '1', '500m', '2.5')."
  type        = string
  default     = "1"

  validation {
    condition     = can(regex("^(0*[1-9][0-9]*(\\.[0-9]*)?|0+\\.[0-9]*[1-9][0-9]*)(m|k|M|G|T|P|E|Ki|Mi|Gi|Ti|Pi|Ei)?$", var.runner_cpu_request))
    error_message = "runner_cpu_request must be a positive Kubernetes resource quantity (e.g. '1', '500m', '2.5')."
  }
}

variable "runner_memory_request" {
  description = "Memory resource request for runner pods (Kubernetes quantity, e.g. '2Gi', '512Mi')."
  type        = string
  default     = "2Gi"

  validation {
    condition     = can(regex("^(0*[1-9][0-9]*(\\.[0-9]*)?|0+\\.[0-9]*[1-9][0-9]*)(m|k|M|G|T|P|E|Ki|Mi|Gi|Ti|Pi|Ei)?$", var.runner_memory_request))
    error_message = "runner_memory_request must be a positive Kubernetes resource quantity (e.g. '2Gi', '512Mi')."
  }
}

# -----------------------------------------------------------------------------
# GitHub App Credentials (sensitive)
# -----------------------------------------------------------------------------

variable "github_app_id" {
  description = "GitHub App ID (numeric string). See README for setup instructions."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.github_app_id) > 0
    error_message = "github_app_id must not be empty."
  }

  validation {
    condition     = can(regex("^[1-9][0-9]*$", var.github_app_id))
    error_message = "github_app_id must be a positive integer (digits only, no leading zeros)."
  }

  validation {
    condition     = !contains(["REPLACE_ME", "123456"], var.github_app_id)
    error_message = "github_app_id contains a placeholder value. Provide a real GitHub App ID (see README)."
  }
}

variable "github_app_installation_id" {
  description = "GitHub App Installation ID (numeric string). See README for setup instructions."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.github_app_installation_id) > 0
    error_message = "github_app_installation_id must not be empty."
  }

  validation {
    condition     = can(regex("^[1-9][0-9]*$", var.github_app_installation_id))
    error_message = "github_app_installation_id must be a positive integer (digits only, no leading zeros)."
  }

  validation {
    condition     = !contains(["REPLACE_ME", "12345678"], var.github_app_installation_id)
    error_message = "github_app_installation_id contains a placeholder value. Provide a real GitHub App Installation ID (see README)."
  }
}

variable "github_app_private_key" {
  description = "GitHub App private key in PEM format. Mutually exclusive with github_app_private_key_file."
  type        = string
  sensitive   = true
  default     = ""

  validation {
    condition     = length(var.github_app_private_key) > 0 || length(var.github_app_private_key_file) > 0
    error_message = "Provide the GitHub App private key via github_app_private_key or github_app_private_key_file."
  }

  validation {
    condition     = var.github_app_private_key == "" || (can(regex("-----BEGIN", var.github_app_private_key)) && can(regex("-----END", var.github_app_private_key)))
    error_message = "github_app_private_key must be PEM-encoded (must contain '-----BEGIN' and '-----END' markers)."
  }

  validation {
    condition     = !contains(["REPLACE_ME"], var.github_app_private_key)
    error_message = "github_app_private_key contains a placeholder value. Provide a real PEM private key."
  }
}

variable "github_app_private_key_file" {
  description = "Path to a file containing the GitHub App private key in PEM format. Used instead of github_app_private_key."
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# Secrets Store CSI Driver & ASCP Chart Versions
# -----------------------------------------------------------------------------

variable "secrets_store_csi_chart_version" {
  description = "Exact semver version of the Secrets Store CSI Driver Helm chart (e.g. 1.4.7)."
  type        = string
  default     = "1.4.7"

  validation {
    condition     = can(regex("^\\d+\\.\\d+\\.\\d+$", var.secrets_store_csi_chart_version))
    error_message = "secrets_store_csi_chart_version must be an exact semantic version (e.g. 'X.Y.Z'). Ranges, wildcards, and floating tags are not allowed."
  }
}

variable "ascp_chart_version" {
  description = "Exact semver version of the AWS Secrets and Configuration Provider (ASCP) Helm chart (e.g. 0.3.11)."
  type        = string
  default     = "0.3.11"

  validation {
    condition     = can(regex("^\\d+\\.\\d+\\.\\d+$", var.ascp_chart_version))
    error_message = "ascp_chart_version must be an exact semantic version (e.g. 'X.Y.Z'). Ranges, wildcards, and floating tags are not allowed."
  }
}

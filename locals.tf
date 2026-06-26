# -----------------------------------------------------------------------------
# Derived Names, Tags, and Shared Validation Predicates
# -----------------------------------------------------------------------------

locals {
  # ---------------------------------------------------------------------------
  # Supported Kubernetes versions (EKS-supported minor versions)
  # Requirement 3.2
  # ---------------------------------------------------------------------------
  supported_k8s_versions = ["1.30", "1.31", "1.32", "1.33", "1.34", "1.35", "1.36"]

  # ---------------------------------------------------------------------------
  # Documented placeholder credential values that MUST be rejected
  # Requirements 6.4, 6.5, 10.8
  # ---------------------------------------------------------------------------
  placeholder_credentials = ["REPLACE_ME", "123456", "12345678"]

  # ---------------------------------------------------------------------------
  # Derived cluster name and common tags
  # Used for Karpenter discovery and resource identification
  # ---------------------------------------------------------------------------
  cluster_name = "eks-arc-runners"

  common_tags = {
    Project                  = "eks-arc-runners"
    ManagedBy                = "terraform"
    "karpenter.sh/discovery" = local.cluster_name
  }

  # ---------------------------------------------------------------------------
  # Resolved runner group — falls back to "default" when var.runner_group is
  # empty. The variable already validates non-empty and defaults to "default",
  # so this local provides a single reference point for downstream modules.
  # Requirement 7.2
  # ---------------------------------------------------------------------------
  resolved_runner_group = length(var.runner_group) > 0 ? var.runner_group : "default"

  # Resolve private key: file path takes precedence over inline value
  github_app_private_key = var.github_app_private_key_file != "" ? file(var.github_app_private_key_file) : var.github_app_private_key

  # ---------------------------------------------------------------------------
  # Pure validation predicates (reusable references for modules and tests)
  # These mirror the logic in variables.tf validation blocks so that child
  # modules, tests, and preconditions can reference them without duplicating
  # regex patterns or threshold constants.
  # ---------------------------------------------------------------------------

  # Requirement 4.1, 5.1, 7.1 — exact semver, no ranges/wildcards/floating tags
  is_exact_semver = can(regex("^\\d+\\.\\d+\\.\\d+$", "placeholder"))
  # Usage: can(regex("^\\d+\\.\\d+\\.\\d+$", value))

  # Bounded integer check: true iff n is an integer within [lo, hi]
  # Usage: value >= lo && value <= hi && value == floor(value)
  # (Terraform locals cannot be parameterized functions, so this documents the
  # pattern; actual checks inline the expression.)

  # Requirements 6.4, 6.5 — positive integer string (digits only, no leading zero)
  # Usage: can(regex("^[1-9][0-9]*$", value))
  is_positive_int_str_pattern = "^[1-9][0-9]*$"

  # Requirements 6.4, 6.5 — PEM envelope detection
  # Usage: can(regex("-----BEGIN", value)) && can(regex("-----END", value))
  is_pem_begin_marker = "-----BEGIN"
  is_pem_end_marker   = "-----END"

  # Requirement 10.8 — placeholder detection
  # Usage: contains(local.placeholder_credentials, value)

  # Requirement 1.6 — state key length bounds
  key_len_min = 1
  key_len_max = 1024

  # Requirement 8.1 — positive Kubernetes quantity pattern
  quantity_positive_pattern = "^(0*[1-9][0-9]*(\\.[0-9]*)?|0+\\.[0-9]*[1-9][0-9]*)(m|k|M|G|T|P|E|Ki|Mi|Gi|Ti|Pi|Ei)?$"
}

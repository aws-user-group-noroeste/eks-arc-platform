# Feature: eks-arc-runners, Property 3: Exact chart-version pinning
# Accept iff matches ^\d+\.\d+\.\d+$
# Validates: Requirements 4.1, 5.1, 5.5, 7.1, 11.1, 11.6

mock_provider "aws" {}
mock_provider "kubernetes" {}
mock_provider "helm" {}

override_module {
  target = module.vpc
}

override_module {
  target = module.eks
}

override_module {
  target = module.karpenter
}

override_module {
  target = module.arc_controller
}

override_module {
  target = module.secrets
}

override_module {
  target = module.runner_scale_set
}

override_module {
  target = module.secrets_store_csi
}

override_module {
  target = module.external_secrets
}

variables {
  # Valid defaults for required vars not under test
  state_key                      = "test/terraform.tfstate"
  arc_controller_chart_version   = "0.9.3"
  runner_scale_set_chart_version = "0.9.3"
  github_org                     = "test-org"
  runner_labels                  = ["self-hosted"]
  github_app_id                  = "999999"
  github_app_installation_id     = "88888888"
  github_app_private_key         = "-----BEGIN RSA PRIVATE KEY-----\nMIIBogIBAAJBALRiMLAH\n-----END RSA PRIVATE KEY-----"
}

# =============================================================================
# karpenter_chart_version (default "1.0.6")
# =============================================================================

# --- Accept cases ---

run "karpenter_accept_simple" {
  command = plan

  variables {
    karpenter_chart_version = "1.2.3"
  }
}

run "karpenter_accept_zero_prefix" {
  command = plan

  variables {
    karpenter_chart_version = "0.9.3"
  }
}

run "karpenter_accept_large_numbers" {
  command = plan

  variables {
    karpenter_chart_version = "10.20.30"
  }
}

run "karpenter_accept_default" {
  command = plan

  variables {
    karpenter_chart_version = "1.0.6"
  }
}

# --- Reject cases ---

run "karpenter_reject_caret_range" {
  command = plan

  variables {
    karpenter_chart_version = "^1.2.3"
  }

  expect_failures = [var.karpenter_chart_version]
}

run "karpenter_reject_tilde_range" {
  command = plan

  variables {
    karpenter_chart_version = "~1.2.3"
  }

  expect_failures = [var.karpenter_chart_version]
}

run "karpenter_reject_gte_range" {
  command = plan

  variables {
    karpenter_chart_version = ">=1.0.0"
  }

  expect_failures = [var.karpenter_chart_version]
}

run "karpenter_reject_wildcard" {
  command = plan

  variables {
    karpenter_chart_version = "1.x"
  }

  expect_failures = [var.karpenter_chart_version]
}

run "karpenter_reject_latest" {
  command = plan

  variables {
    karpenter_chart_version = "latest"
  }

  expect_failures = [var.karpenter_chart_version]
}

run "karpenter_reject_empty" {
  command = plan

  variables {
    karpenter_chart_version = ""
  }

  expect_failures = [var.karpenter_chart_version]
}

run "karpenter_reject_two_parts" {
  command = plan

  variables {
    karpenter_chart_version = "1.2"
  }

  expect_failures = [var.karpenter_chart_version]
}

run "karpenter_reject_four_parts" {
  command = plan

  variables {
    karpenter_chart_version = "1.2.3.4"
  }

  expect_failures = [var.karpenter_chart_version]
}

run "karpenter_reject_v_prefix" {
  command = plan

  variables {
    karpenter_chart_version = "v1.2.3"
  }

  expect_failures = [var.karpenter_chart_version]
}

run "karpenter_reject_prerelease" {
  command = plan

  variables {
    karpenter_chart_version = "1.2.3-beta"
  }

  expect_failures = [var.karpenter_chart_version]
}

# =============================================================================
# arc_controller_chart_version (no default, required)
# =============================================================================

# --- Accept cases ---

run "arc_controller_accept_simple" {
  command = plan

  variables {
    arc_controller_chart_version = "1.2.3"
  }
}

run "arc_controller_accept_zero_prefix" {
  command = plan

  variables {
    arc_controller_chart_version = "0.9.3"
  }
}

run "arc_controller_accept_large_numbers" {
  command = plan

  variables {
    arc_controller_chart_version = "10.20.30"
  }
}

run "arc_controller_accept_147" {
  command = plan

  variables {
    arc_controller_chart_version = "1.4.7"
  }
}

# --- Reject cases ---

run "arc_controller_reject_caret_range" {
  command = plan

  variables {
    arc_controller_chart_version = "^1.2.3"
  }

  expect_failures = [var.arc_controller_chart_version]
}

run "arc_controller_reject_tilde_range" {
  command = plan

  variables {
    arc_controller_chart_version = "~1.2.3"
  }

  expect_failures = [var.arc_controller_chart_version]
}

run "arc_controller_reject_gte_range" {
  command = plan

  variables {
    arc_controller_chart_version = ">=1.0.0"
  }

  expect_failures = [var.arc_controller_chart_version]
}

run "arc_controller_reject_wildcard" {
  command = plan

  variables {
    arc_controller_chart_version = "1.x"
  }

  expect_failures = [var.arc_controller_chart_version]
}

run "arc_controller_reject_latest" {
  command = plan

  variables {
    arc_controller_chart_version = "latest"
  }

  expect_failures = [var.arc_controller_chart_version]
}

run "arc_controller_reject_empty" {
  command = plan

  variables {
    arc_controller_chart_version = ""
  }

  expect_failures = [var.arc_controller_chart_version]
}

run "arc_controller_reject_two_parts" {
  command = plan

  variables {
    arc_controller_chart_version = "1.2"
  }

  expect_failures = [var.arc_controller_chart_version]
}

run "arc_controller_reject_four_parts" {
  command = plan

  variables {
    arc_controller_chart_version = "1.2.3.4"
  }

  expect_failures = [var.arc_controller_chart_version]
}

run "arc_controller_reject_v_prefix" {
  command = plan

  variables {
    arc_controller_chart_version = "v1.2.3"
  }

  expect_failures = [var.arc_controller_chart_version]
}

run "arc_controller_reject_prerelease" {
  command = plan

  variables {
    arc_controller_chart_version = "1.2.3-beta"
  }

  expect_failures = [var.arc_controller_chart_version]
}

# =============================================================================
# runner_scale_set_chart_version (no default, required)
# =============================================================================

# --- Accept cases ---

run "runner_scale_set_accept_simple" {
  command = plan

  variables {
    runner_scale_set_chart_version = "1.2.3"
  }
}

run "runner_scale_set_accept_zero_prefix" {
  command = plan

  variables {
    runner_scale_set_chart_version = "0.9.3"
  }
}

run "runner_scale_set_accept_large_numbers" {
  command = plan

  variables {
    runner_scale_set_chart_version = "10.20.30"
  }
}

run "runner_scale_set_accept_0311" {
  command = plan

  variables {
    runner_scale_set_chart_version = "0.3.11"
  }
}

# --- Reject cases ---

run "runner_scale_set_reject_caret_range" {
  command = plan

  variables {
    runner_scale_set_chart_version = "^1.2.3"
  }

  expect_failures = [var.runner_scale_set_chart_version]
}

run "runner_scale_set_reject_tilde_range" {
  command = plan

  variables {
    runner_scale_set_chart_version = "~1.2.3"
  }

  expect_failures = [var.runner_scale_set_chart_version]
}

run "runner_scale_set_reject_gte_range" {
  command = plan

  variables {
    runner_scale_set_chart_version = ">=1.0.0"
  }

  expect_failures = [var.runner_scale_set_chart_version]
}

run "runner_scale_set_reject_wildcard" {
  command = plan

  variables {
    runner_scale_set_chart_version = "1.x"
  }

  expect_failures = [var.runner_scale_set_chart_version]
}

run "runner_scale_set_reject_latest" {
  command = plan

  variables {
    runner_scale_set_chart_version = "latest"
  }

  expect_failures = [var.runner_scale_set_chart_version]
}

run "runner_scale_set_reject_empty" {
  command = plan

  variables {
    runner_scale_set_chart_version = ""
  }

  expect_failures = [var.runner_scale_set_chart_version]
}

run "runner_scale_set_reject_two_parts" {
  command = plan

  variables {
    runner_scale_set_chart_version = "1.2"
  }

  expect_failures = [var.runner_scale_set_chart_version]
}

run "runner_scale_set_reject_four_parts" {
  command = plan

  variables {
    runner_scale_set_chart_version = "1.2.3.4"
  }

  expect_failures = [var.runner_scale_set_chart_version]
}

run "runner_scale_set_reject_v_prefix" {
  command = plan

  variables {
    runner_scale_set_chart_version = "v1.2.3"
  }

  expect_failures = [var.runner_scale_set_chart_version]
}

run "runner_scale_set_reject_prerelease" {
  command = plan

  variables {
    runner_scale_set_chart_version = "1.2.3-beta"
  }

  expect_failures = [var.runner_scale_set_chart_version]
}

# =============================================================================
# secrets_store_csi_chart_version (default "1.4.7")
# =============================================================================

# --- Accept cases ---

run "secrets_store_csi_accept_simple" {
  command = plan

  variables {
    secrets_store_csi_chart_version = "1.2.3"
  }
}

run "secrets_store_csi_accept_zero_prefix" {
  command = plan

  variables {
    secrets_store_csi_chart_version = "0.9.3"
  }
}

run "secrets_store_csi_accept_large_numbers" {
  command = plan

  variables {
    secrets_store_csi_chart_version = "10.20.30"
  }
}

run "secrets_store_csi_accept_default" {
  command = plan

  variables {
    secrets_store_csi_chart_version = "1.4.7"
  }
}

# --- Reject cases ---

run "secrets_store_csi_reject_caret_range" {
  command = plan

  variables {
    secrets_store_csi_chart_version = "^1.2.3"
  }

  expect_failures = [var.secrets_store_csi_chart_version]
}

run "secrets_store_csi_reject_tilde_range" {
  command = plan

  variables {
    secrets_store_csi_chart_version = "~1.2.3"
  }

  expect_failures = [var.secrets_store_csi_chart_version]
}

run "secrets_store_csi_reject_gte_range" {
  command = plan

  variables {
    secrets_store_csi_chart_version = ">=1.0.0"
  }

  expect_failures = [var.secrets_store_csi_chart_version]
}

run "secrets_store_csi_reject_wildcard" {
  command = plan

  variables {
    secrets_store_csi_chart_version = "1.x"
  }

  expect_failures = [var.secrets_store_csi_chart_version]
}

run "secrets_store_csi_reject_latest" {
  command = plan

  variables {
    secrets_store_csi_chart_version = "latest"
  }

  expect_failures = [var.secrets_store_csi_chart_version]
}

run "secrets_store_csi_reject_empty" {
  command = plan

  variables {
    secrets_store_csi_chart_version = ""
  }

  expect_failures = [var.secrets_store_csi_chart_version]
}

run "secrets_store_csi_reject_two_parts" {
  command = plan

  variables {
    secrets_store_csi_chart_version = "1.2"
  }

  expect_failures = [var.secrets_store_csi_chart_version]
}

run "secrets_store_csi_reject_four_parts" {
  command = plan

  variables {
    secrets_store_csi_chart_version = "1.2.3.4"
  }

  expect_failures = [var.secrets_store_csi_chart_version]
}

run "secrets_store_csi_reject_v_prefix" {
  command = plan

  variables {
    secrets_store_csi_chart_version = "v1.2.3"
  }

  expect_failures = [var.secrets_store_csi_chart_version]
}

run "secrets_store_csi_reject_prerelease" {
  command = plan

  variables {
    secrets_store_csi_chart_version = "1.2.3-beta"
  }

  expect_failures = [var.secrets_store_csi_chart_version]
}

# =============================================================================
# ascp_chart_version (default "0.3.11")
# =============================================================================

# --- Accept cases ---

run "ascp_accept_simple" {
  command = plan

  variables {
    ascp_chart_version = "1.2.3"
  }
}

run "ascp_accept_zero_prefix" {
  command = plan

  variables {
    ascp_chart_version = "0.9.3"
  }
}

run "ascp_accept_large_numbers" {
  command = plan

  variables {
    ascp_chart_version = "10.20.30"
  }
}

run "ascp_accept_default" {
  command = plan

  variables {
    ascp_chart_version = "0.3.11"
  }
}

# --- Reject cases ---

run "ascp_reject_caret_range" {
  command = plan

  variables {
    ascp_chart_version = "^1.2.3"
  }

  expect_failures = [var.ascp_chart_version]
}

run "ascp_reject_tilde_range" {
  command = plan

  variables {
    ascp_chart_version = "~1.2.3"
  }

  expect_failures = [var.ascp_chart_version]
}

run "ascp_reject_gte_range" {
  command = plan

  variables {
    ascp_chart_version = ">=1.0.0"
  }

  expect_failures = [var.ascp_chart_version]
}

run "ascp_reject_wildcard" {
  command = plan

  variables {
    ascp_chart_version = "1.x"
  }

  expect_failures = [var.ascp_chart_version]
}

run "ascp_reject_latest" {
  command = plan

  variables {
    ascp_chart_version = "latest"
  }

  expect_failures = [var.ascp_chart_version]
}

run "ascp_reject_empty" {
  command = plan

  variables {
    ascp_chart_version = ""
  }

  expect_failures = [var.ascp_chart_version]
}

run "ascp_reject_two_parts" {
  command = plan

  variables {
    ascp_chart_version = "1.2"
  }

  expect_failures = [var.ascp_chart_version]
}

run "ascp_reject_four_parts" {
  command = plan

  variables {
    ascp_chart_version = "1.2.3.4"
  }

  expect_failures = [var.ascp_chart_version]
}

run "ascp_reject_v_prefix" {
  command = plan

  variables {
    ascp_chart_version = "v1.2.3"
  }

  expect_failures = [var.ascp_chart_version]
}

run "ascp_reject_prerelease" {
  command = plan

  variables {
    ascp_chart_version = "1.2.3-beta"
  }

  expect_failures = [var.ascp_chart_version]
}

# Feature: eks-arc-runners, Property 7: Positive runner resource requests
# -----------------------------------------------------------------------------
# Property 7: Positive runner resource requests — accept iff the quantity parses
# to a strictly positive value.
#
# The validation regex for both runner_cpu_request and runner_memory_request:
#   ^(0*[1-9][0-9]*(\.[0-9]*)?|0+\.[0-9]*[1-9][0-9]*)(m|k|M|G|T|P|E|Ki|Mi|Gi|Ti|Pi|Ei)?$
#
# Test cases for each variable:
#   Accept: "1", "500m", "2.5", "2Gi", "512Mi", "100m", "0.5", "4", "1Ki"
#   Reject: "0", "0m", "0Gi", "-1", "", "abc", "0.0"
#
# Validates: Requirements 8.1
# -----------------------------------------------------------------------------

mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-east-1a", "us-east-1b", "us-east-1c"]
    }
  }
}
mock_provider "kubernetes" {}
mock_provider "helm" {}

override_module {
  target = module.vpc
  outputs = {
    vpc_id             = "vpc-mock12345"
    private_subnet_ids = ["subnet-priv1", "subnet-priv2"]
    public_subnet_ids  = ["subnet-pub1", "subnet-pub2"]
    azs                = ["us-east-1a", "us-east-1b"]
  }
}

override_module {
  target = module.eks
  outputs = {
    cluster_name                       = "test-cluster"
    cluster_endpoint                   = "https://mock-endpoint.eks.amazonaws.com"
    cluster_certificate_authority_data = "bW9jay1jYS1kYXRh"
    oidc_provider_arn                  = "arn:aws:iam::123456789012:oidc-provider/mock"
    oidc_provider_url                  = "oidc.eks.us-east-1.amazonaws.com/id/MOCK"
    cluster_security_group_id          = "sg-mock1"
    node_security_group_id             = "sg-mock2"
    kubeconfig_command                 = "aws eks update-kubeconfig --name test-cluster"
  }
}

override_module {
  target = module.karpenter
}

override_module {
  target = module.arc_controller
}

override_module {
  target = module.secrets
  outputs = {
    secret_arn        = "arn:aws:secretsmanager:us-east-1:123456789012:secret:test-cluster-github-app-credentials-MOCK"
    kms_key_arn       = "arn:aws:kms:us-east-1:123456789012:key/mock-key-id"
    irsa_role_arn     = "arn:aws:iam::123456789012:role/test-cluster-runner-secrets-access"
    secret_name       = "smoke-cluster-github-app-credentials"
    eso_irsa_role_arn = "arn:aws:iam::123456789012:role/smoke-cluster-eso-secrets-access"
  }
}

override_module {
  target = module.runner_scale_set
}

override_module {
  target = module.external_secrets
}

# --- Required variables (no defaults) supplied with valid values ---
variables {
  state_key                      = "test/terraform.tfstate"
  arc_controller_chart_version   = "0.9.3"
  runner_scale_set_chart_version = "0.9.3"
  github_org                     = "test-org"
  runner_labels                  = ["self-hosted"]
  github_app_id                  = "123456789"
  github_app_installation_id     = "987654321"
  github_app_private_key         = "-----BEGIN RSA PRIVATE KEY-----\nMIIBogIBAAJBALRiMLAH\n-----END RSA PRIVATE KEY-----"
}

# =============================================================================
# runner_cpu_request — Accept cases
# =============================================================================

# --- Accept: "1" (integer) ---
run "runner_cpu_request_accept_integer" {
  command = plan

  variables {
    runner_cpu_request = "1"
  }

  assert {
    condition     = var.runner_cpu_request == "1"
    error_message = "Expected runner_cpu_request to accept '1'."
  }
}

# --- Accept: "500m" (milliCPU) ---
run "runner_cpu_request_accept_millicpu" {
  command = plan

  variables {
    runner_cpu_request = "500m"
  }

  assert {
    condition     = var.runner_cpu_request == "500m"
    error_message = "Expected runner_cpu_request to accept '500m'."
  }
}

# --- Accept: "2.5" (decimal) ---
run "runner_cpu_request_accept_decimal" {
  command = plan

  variables {
    runner_cpu_request = "2.5"
  }

  assert {
    condition     = var.runner_cpu_request == "2.5"
    error_message = "Expected runner_cpu_request to accept '2.5'."
  }
}

# --- Accept: "100m" (milliCPU) ---
run "runner_cpu_request_accept_100m" {
  command = plan

  variables {
    runner_cpu_request = "100m"
  }

  assert {
    condition     = var.runner_cpu_request == "100m"
    error_message = "Expected runner_cpu_request to accept '100m'."
  }
}

# --- Accept: "0.5" (fractional) ---
run "runner_cpu_request_accept_fractional" {
  command = plan

  variables {
    runner_cpu_request = "0.5"
  }

  assert {
    condition     = var.runner_cpu_request == "0.5"
    error_message = "Expected runner_cpu_request to accept '0.5'."
  }
}

# --- Accept: "4" (whole number) ---
run "runner_cpu_request_accept_whole" {
  command = plan

  variables {
    runner_cpu_request = "4"
  }

  assert {
    condition     = var.runner_cpu_request == "4"
    error_message = "Expected runner_cpu_request to accept '4'."
  }
}

# --- Accept: "1Ki" (kibibytes suffix) ---
run "runner_cpu_request_accept_ki_suffix" {
  command = plan

  variables {
    runner_cpu_request = "1Ki"
  }

  assert {
    condition     = var.runner_cpu_request == "1Ki"
    error_message = "Expected runner_cpu_request to accept '1Ki'."
  }
}

# =============================================================================
# runner_cpu_request — Reject cases
# =============================================================================

# --- Reject: "0" (zero) ---
run "runner_cpu_request_reject_zero" {
  command = plan

  variables {
    runner_cpu_request = "0"
  }

  expect_failures = [var.runner_cpu_request]
}

# --- Reject: "0m" (zero with suffix) ---
run "runner_cpu_request_reject_zero_with_suffix" {
  command = plan

  variables {
    runner_cpu_request = "0m"
  }

  expect_failures = [var.runner_cpu_request]
}

# --- Reject: "0Gi" (zero with binary suffix) ---
run "runner_cpu_request_reject_zero_gi" {
  command = plan

  variables {
    runner_cpu_request = "0Gi"
  }

  expect_failures = [var.runner_cpu_request]
}

# --- Reject: "-1" (negative) ---
run "runner_cpu_request_reject_negative" {
  command = plan

  variables {
    runner_cpu_request = "-1"
  }

  expect_failures = [var.runner_cpu_request]
}

# --- Reject: "" (empty) ---
run "runner_cpu_request_reject_empty" {
  command = plan

  variables {
    runner_cpu_request = ""
  }

  expect_failures = [var.runner_cpu_request]
}

# --- Reject: "abc" (non-numeric) ---
run "runner_cpu_request_reject_non_numeric" {
  command = plan

  variables {
    runner_cpu_request = "abc"
  }

  expect_failures = [var.runner_cpu_request]
}

# --- Reject: "0.0" (zero decimal) ---
run "runner_cpu_request_reject_zero_decimal" {
  command = plan

  variables {
    runner_cpu_request = "0.0"
  }

  expect_failures = [var.runner_cpu_request]
}

# =============================================================================
# runner_memory_request — Accept cases
# =============================================================================

# --- Accept: "2Gi" (gibibytes) ---
run "runner_memory_request_accept_gibibytes" {
  command = plan

  variables {
    runner_memory_request = "2Gi"
  }

  assert {
    condition     = var.runner_memory_request == "2Gi"
    error_message = "Expected runner_memory_request to accept '2Gi'."
  }
}

# --- Accept: "512Mi" (mebibytes) ---
run "runner_memory_request_accept_mebibytes" {
  command = plan

  variables {
    runner_memory_request = "512Mi"
  }

  assert {
    condition     = var.runner_memory_request == "512Mi"
    error_message = "Expected runner_memory_request to accept '512Mi'."
  }
}

# --- Accept: "1" (byte count) ---
run "runner_memory_request_accept_integer" {
  command = plan

  variables {
    runner_memory_request = "1"
  }

  assert {
    condition     = var.runner_memory_request == "1"
    error_message = "Expected runner_memory_request to accept '1'."
  }
}

# --- Accept: "500m" (millibyte) ---
run "runner_memory_request_accept_millis" {
  command = plan

  variables {
    runner_memory_request = "500m"
  }

  assert {
    condition     = var.runner_memory_request == "500m"
    error_message = "Expected runner_memory_request to accept '500m'."
  }
}

# --- Accept: "2.5" (decimal) ---
run "runner_memory_request_accept_decimal" {
  command = plan

  variables {
    runner_memory_request = "2.5"
  }

  assert {
    condition     = var.runner_memory_request == "2.5"
    error_message = "Expected runner_memory_request to accept '2.5'."
  }
}

# --- Accept: "0.5" (fractional) ---
run "runner_memory_request_accept_fractional" {
  command = plan

  variables {
    runner_memory_request = "0.5"
  }

  assert {
    condition     = var.runner_memory_request == "0.5"
    error_message = "Expected runner_memory_request to accept '0.5'."
  }
}

# --- Accept: "4" (whole number) ---
run "runner_memory_request_accept_whole" {
  command = plan

  variables {
    runner_memory_request = "4"
  }

  assert {
    condition     = var.runner_memory_request == "4"
    error_message = "Expected runner_memory_request to accept '4'."
  }
}

# --- Accept: "1Ki" (kibibytes suffix) ---
run "runner_memory_request_accept_ki_suffix" {
  command = plan

  variables {
    runner_memory_request = "1Ki"
  }

  assert {
    condition     = var.runner_memory_request == "1Ki"
    error_message = "Expected runner_memory_request to accept '1Ki'."
  }
}

# =============================================================================
# runner_memory_request — Reject cases
# =============================================================================

# --- Reject: "0" (zero) ---
run "runner_memory_request_reject_zero" {
  command = plan

  variables {
    runner_memory_request = "0"
  }

  expect_failures = [var.runner_memory_request]
}

# --- Reject: "0m" (zero with suffix) ---
run "runner_memory_request_reject_zero_with_suffix" {
  command = plan

  variables {
    runner_memory_request = "0m"
  }

  expect_failures = [var.runner_memory_request]
}

# --- Reject: "0Gi" (zero with binary suffix) ---
run "runner_memory_request_reject_zero_gi" {
  command = plan

  variables {
    runner_memory_request = "0Gi"
  }

  expect_failures = [var.runner_memory_request]
}

# --- Reject: "-1" (negative) ---
run "runner_memory_request_reject_negative" {
  command = plan

  variables {
    runner_memory_request = "-1"
  }

  expect_failures = [var.runner_memory_request]
}

# --- Reject: "" (empty) ---
run "runner_memory_request_reject_empty" {
  command = plan

  variables {
    runner_memory_request = ""
  }

  expect_failures = [var.runner_memory_request]
}

# --- Reject: "abc" (non-numeric) ---
run "runner_memory_request_reject_non_numeric" {
  command = plan

  variables {
    runner_memory_request = "abc"
  }

  expect_failures = [var.runner_memory_request]
}

# --- Reject: "0.0" (zero decimal) ---
run "runner_memory_request_reject_zero_decimal" {
  command = plan

  variables {
    runner_memory_request = "0.0"
  }

  expect_failures = [var.runner_memory_request]
}

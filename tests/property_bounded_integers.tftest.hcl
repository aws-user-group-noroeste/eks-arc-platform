# Feature: eks-arc-runners, Property 2: Bounded integer parameters
# -----------------------------------------------------------------------------
# Property 2: Bounded integer parameters — accept iff integer and lo <= n <= hi
#
# Parameterized over the four bounded-integer variables:
#   karpenter_consolidate_after_seconds [0, 3600]
#   nodepool_cpu_limit                  [1, 10000]
#   max_runners                         [1, 1000]
#   node_grace_period_seconds           [0, 3600]
#
# For each variable, tests:
#   Accept: lower bound (lo), upper bound (hi), midpoint
#   Reject: below lower bound (lo - 1), above upper bound (hi + 1), non-integer
#
# Validates: Requirements 4.6, 4.7, 7.4, 7.5, 7.9, 9.5
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
# karpenter_consolidate_after_seconds [0, 3600]
# =============================================================================

# --- Accept: lower bound (0) ---
run "karpenter_consolidate_after_seconds_accept_lower_bound" {
  command = plan

  variables {
    karpenter_consolidate_after_seconds = 0
  }

  assert {
    condition     = var.karpenter_consolidate_after_seconds == 0
    error_message = "Expected karpenter_consolidate_after_seconds to accept lower bound 0."
  }
}

# --- Accept: upper bound (3600) ---
run "karpenter_consolidate_after_seconds_accept_upper_bound" {
  command = plan

  variables {
    karpenter_consolidate_after_seconds = 3600
  }

  assert {
    condition     = var.karpenter_consolidate_after_seconds == 3600
    error_message = "Expected karpenter_consolidate_after_seconds to accept upper bound 3600."
  }
}

# --- Accept: midpoint (1800) ---
run "karpenter_consolidate_after_seconds_accept_midpoint" {
  command = plan

  variables {
    karpenter_consolidate_after_seconds = 1800
  }

  assert {
    condition     = var.karpenter_consolidate_after_seconds == 1800
    error_message = "Expected karpenter_consolidate_after_seconds to accept midpoint 1800."
  }
}

# --- Reject: below lower bound (-1) ---
run "karpenter_consolidate_after_seconds_reject_below_lower_bound" {
  command = plan

  variables {
    karpenter_consolidate_after_seconds = -1
  }

  expect_failures = [var.karpenter_consolidate_after_seconds]
}

# --- Reject: above upper bound (3601) ---
run "karpenter_consolidate_after_seconds_reject_above_upper_bound" {
  command = plan

  variables {
    karpenter_consolidate_after_seconds = 3601
  }

  expect_failures = [var.karpenter_consolidate_after_seconds]
}

# --- Reject: non-integer (1.5) ---
run "karpenter_consolidate_after_seconds_reject_non_integer" {
  command = plan

  variables {
    karpenter_consolidate_after_seconds = 1.5
  }

  expect_failures = [var.karpenter_consolidate_after_seconds]
}

# =============================================================================
# nodepool_cpu_limit [1, 10000]
# =============================================================================

# --- Accept: lower bound (1) ---
run "nodepool_cpu_limit_accept_lower_bound" {
  command = plan

  variables {
    nodepool_cpu_limit = 1
  }

  assert {
    condition     = var.nodepool_cpu_limit == 1
    error_message = "Expected nodepool_cpu_limit to accept lower bound 1."
  }
}

# --- Accept: upper bound (10000) ---
run "nodepool_cpu_limit_accept_upper_bound" {
  command = plan

  variables {
    nodepool_cpu_limit = 10000
  }

  assert {
    condition     = var.nodepool_cpu_limit == 10000
    error_message = "Expected nodepool_cpu_limit to accept upper bound 10000."
  }
}

# --- Accept: midpoint (5000) ---
run "nodepool_cpu_limit_accept_midpoint" {
  command = plan

  variables {
    nodepool_cpu_limit = 5000
  }

  assert {
    condition     = var.nodepool_cpu_limit == 5000
    error_message = "Expected nodepool_cpu_limit to accept midpoint 5000."
  }
}

# --- Reject: below lower bound (0) ---
run "nodepool_cpu_limit_reject_below_lower_bound" {
  command = plan

  variables {
    nodepool_cpu_limit = 0
  }

  expect_failures = [var.nodepool_cpu_limit]
}

# --- Reject: above upper bound (10001) ---
run "nodepool_cpu_limit_reject_above_upper_bound" {
  command = plan

  variables {
    nodepool_cpu_limit = 10001
  }

  expect_failures = [var.nodepool_cpu_limit]
}

# --- Reject: non-integer (1.5) ---
run "nodepool_cpu_limit_reject_non_integer" {
  command = plan

  variables {
    nodepool_cpu_limit = 1.5
  }

  expect_failures = [var.nodepool_cpu_limit]
}

# =============================================================================
# max_runners [1, 1000]
# =============================================================================

# --- Accept: lower bound (1) ---
run "max_runners_accept_lower_bound" {
  command = plan

  variables {
    max_runners = 1
  }

  assert {
    condition     = var.max_runners == 1
    error_message = "Expected max_runners to accept lower bound 1."
  }
}

# --- Accept: upper bound (1000) ---
run "max_runners_accept_upper_bound" {
  command = plan

  variables {
    max_runners = 1000
  }

  assert {
    condition     = var.max_runners == 1000
    error_message = "Expected max_runners to accept upper bound 1000."
  }
}

# --- Accept: midpoint (500) ---
run "max_runners_accept_midpoint" {
  command = plan

  variables {
    max_runners = 500
  }

  assert {
    condition     = var.max_runners == 500
    error_message = "Expected max_runners to accept midpoint 500."
  }
}

# --- Reject: below lower bound (0) ---
run "max_runners_reject_below_lower_bound" {
  command = plan

  variables {
    max_runners = 0
  }

  expect_failures = [var.max_runners]
}

# --- Reject: above upper bound (1001) ---
run "max_runners_reject_above_upper_bound" {
  command = plan

  variables {
    max_runners = 1001
  }

  expect_failures = [var.max_runners]
}

# --- Reject: non-integer (1.5) ---
run "max_runners_reject_non_integer" {
  command = plan

  variables {
    max_runners = 1.5
  }

  expect_failures = [var.max_runners]
}

# =============================================================================
# node_grace_period_seconds [0, 3600]
# =============================================================================

# --- Accept: lower bound (0) ---
run "node_grace_period_seconds_accept_lower_bound" {
  command = plan

  variables {
    node_grace_period_seconds = 0
  }

  assert {
    condition     = var.node_grace_period_seconds == 0
    error_message = "Expected node_grace_period_seconds to accept lower bound 0."
  }
}

# --- Accept: upper bound (3600) ---
run "node_grace_period_seconds_accept_upper_bound" {
  command = plan

  variables {
    node_grace_period_seconds = 3600
  }

  assert {
    condition     = var.node_grace_period_seconds == 3600
    error_message = "Expected node_grace_period_seconds to accept upper bound 3600."
  }
}

# --- Accept: midpoint (1800) ---
run "node_grace_period_seconds_accept_midpoint" {
  command = plan

  variables {
    node_grace_period_seconds = 1800
  }

  assert {
    condition     = var.node_grace_period_seconds == 1800
    error_message = "Expected node_grace_period_seconds to accept midpoint 1800."
  }
}

# --- Reject: below lower bound (-1) ---
run "node_grace_period_seconds_reject_below_lower_bound" {
  command = plan

  variables {
    node_grace_period_seconds = -1
  }

  expect_failures = [var.node_grace_period_seconds]
}

# --- Reject: above upper bound (3601) ---
run "node_grace_period_seconds_reject_above_upper_bound" {
  command = plan

  variables {
    node_grace_period_seconds = 3601
  }

  expect_failures = [var.node_grace_period_seconds]
}

# --- Reject: non-integer (1.5) ---
run "node_grace_period_seconds_reject_non_integer" {
  command = plan

  variables {
    node_grace_period_seconds = 1.5
  }

  expect_failures = [var.node_grace_period_seconds]
}

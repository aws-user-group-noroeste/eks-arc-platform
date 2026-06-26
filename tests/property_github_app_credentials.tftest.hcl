# Feature: eks-arc-runners, Property 4: GitHub App credential validation
# Accept iff all three non-empty, ids match ^[1-9][0-9]*$, key is PEM, and none is a placeholder
# Validates: Requirements 6.4, 6.5, 10.8

mock_provider "aws" {}
mock_provider "kubernetes" {}
mock_provider "helm" {}

variables {
  # Valid defaults for required vars not under test
  state_key                      = "terraform/test/terraform.tfstate"
  arc_controller_chart_version   = "0.9.3"
  runner_scale_set_chart_version = "0.9.3"
  github_org                     = "test-org"
  runner_labels                  = ["self-hosted"]
}

# --- Accept cases ---

# Accept: valid credential triple
run "accept_valid_credentials" {
  command = plan

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
    target = module.external_secrets
  }
  override_module {
    target = module.runner_scale_set
  }

  variables {
    github_app_id              = "999999"
    github_app_installation_id = "88888888"
    github_app_private_key     = "-----BEGIN RSA PRIVATE KEY-----\nMIIBogIBAAJBALRiMLAH\n-----END RSA PRIVATE KEY-----"
  }
}

# Accept: single-digit valid app_id
run "accept_single_digit_app_id" {
  command = plan

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
    target = module.external_secrets
  }
  override_module {
    target = module.runner_scale_set
  }

  variables {
    github_app_id              = "1"
    github_app_installation_id = "88888888"
    github_app_private_key     = "-----BEGIN RSA PRIVATE KEY-----\ntest\n-----END RSA PRIVATE KEY-----"
  }
}

# Accept: large numeric ids
run "accept_large_ids" {
  command = plan

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
    target = module.external_secrets
  }
  override_module {
    target = module.runner_scale_set
  }

  variables {
    github_app_id              = "9999999999"
    github_app_installation_id = "1234567890123"
    github_app_private_key     = "-----BEGIN EC PRIVATE KEY-----\ndata\n-----END EC PRIVATE KEY-----"
  }
}

# Accept: different valid PEM type
run "accept_different_pem_type" {
  command = plan

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
    target = module.external_secrets
  }
  override_module {
    target = module.runner_scale_set
  }

  variables {
    github_app_id              = "42"
    github_app_installation_id = "100"
    github_app_private_key     = "-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBg\n-----END PRIVATE KEY-----"
  }
}

# --- Reject cases: empty values ---

# Reject: empty app_id
run "reject_empty_app_id" {
  command = plan

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
    target = module.external_secrets
  }
  override_module {
    target = module.runner_scale_set
  }

  variables {
    github_app_id              = ""
    github_app_installation_id = "88888888"
    github_app_private_key     = "-----BEGIN RSA PRIVATE KEY-----\ntest\n-----END RSA PRIVATE KEY-----"
  }

  expect_failures = [var.github_app_id]
}

# Reject: empty installation_id
run "reject_empty_installation_id" {
  command = plan

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
    target = module.external_secrets
  }
  override_module {
    target = module.runner_scale_set
  }

  variables {
    github_app_id              = "999999"
    github_app_installation_id = ""
    github_app_private_key     = "-----BEGIN RSA PRIVATE KEY-----\ntest\n-----END RSA PRIVATE KEY-----"
  }

  expect_failures = [var.github_app_installation_id]
}

# Reject: empty private_key
run "reject_empty_private_key" {
  command = plan

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
    target = module.external_secrets
  }
  override_module {
    target = module.runner_scale_set
  }

  variables {
    github_app_id              = "999999"
    github_app_installation_id = "88888888"
    github_app_private_key     = ""
  }

  expect_failures = [var.github_app_private_key]
}

# --- Reject cases: non-numeric ids ---

# Reject: non-numeric app_id
run "reject_non_numeric_app_id" {
  command = plan

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
    target = module.external_secrets
  }
  override_module {
    target = module.runner_scale_set
  }

  variables {
    github_app_id              = "abc"
    github_app_installation_id = "88888888"
    github_app_private_key     = "-----BEGIN RSA PRIVATE KEY-----\ntest\n-----END RSA PRIVATE KEY-----"
  }

  expect_failures = [var.github_app_id]
}

# Reject: non-numeric installation_id
run "reject_non_numeric_installation_id" {
  command = plan

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
    target = module.external_secrets
  }
  override_module {
    target = module.runner_scale_set
  }

  variables {
    github_app_id              = "999999"
    github_app_installation_id = "xyz123"
    github_app_private_key     = "-----BEGIN RSA PRIVATE KEY-----\ntest\n-----END RSA PRIVATE KEY-----"
  }

  expect_failures = [var.github_app_installation_id]
}

# Reject: app_id with special characters
run "reject_special_chars_app_id" {
  command = plan

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
    target = module.external_secrets
  }
  override_module {
    target = module.runner_scale_set
  }

  variables {
    github_app_id              = "12-34"
    github_app_installation_id = "88888888"
    github_app_private_key     = "-----BEGIN RSA PRIVATE KEY-----\ntest\n-----END RSA PRIVATE KEY-----"
  }

  expect_failures = [var.github_app_id]
}

# Reject: installation_id with spaces
run "reject_spaces_installation_id" {
  command = plan

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
    target = module.external_secrets
  }
  override_module {
    target = module.runner_scale_set
  }

  variables {
    github_app_id              = "999999"
    github_app_installation_id = "123 456"
    github_app_private_key     = "-----BEGIN RSA PRIVATE KEY-----\ntest\n-----END RSA PRIVATE KEY-----"
  }

  expect_failures = [var.github_app_installation_id]
}

# --- Reject cases: leading zeros ---

# Reject: leading-zero app_id
run "reject_leading_zero_app_id" {
  command = plan

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
    target = module.external_secrets
  }
  override_module {
    target = module.runner_scale_set
  }

  variables {
    github_app_id              = "012"
    github_app_installation_id = "88888888"
    github_app_private_key     = "-----BEGIN RSA PRIVATE KEY-----\ntest\n-----END RSA PRIVATE KEY-----"
  }

  expect_failures = [var.github_app_id]
}

# Reject: leading-zero installation_id
run "reject_leading_zero_installation_id" {
  command = plan

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
    target = module.external_secrets
  }
  override_module {
    target = module.runner_scale_set
  }

  variables {
    github_app_id              = "999999"
    github_app_installation_id = "0123456"
    github_app_private_key     = "-----BEGIN RSA PRIVATE KEY-----\ntest\n-----END RSA PRIVATE KEY-----"
  }

  expect_failures = [var.github_app_installation_id]
}

# Reject: app_id is just "0"
run "reject_zero_app_id" {
  command = plan

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
    target = module.external_secrets
  }
  override_module {
    target = module.runner_scale_set
  }

  variables {
    github_app_id              = "0"
    github_app_installation_id = "88888888"
    github_app_private_key     = "-----BEGIN RSA PRIVATE KEY-----\ntest\n-----END RSA PRIVATE KEY-----"
  }

  expect_failures = [var.github_app_id]
}

# --- Reject cases: non-PEM private key ---

# Reject: non-PEM key (just a string)
run "reject_non_pem_key" {
  command = plan

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
    target = module.external_secrets
  }
  override_module {
    target = module.runner_scale_set
  }

  variables {
    github_app_id              = "999999"
    github_app_installation_id = "88888888"
    github_app_private_key     = "just-a-string"
  }

  expect_failures = [var.github_app_private_key]
}

# Reject: key with only BEGIN marker
run "reject_key_only_begin" {
  command = plan

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
    target = module.external_secrets
  }
  override_module {
    target = module.runner_scale_set
  }

  variables {
    github_app_id              = "999999"
    github_app_installation_id = "88888888"
    github_app_private_key     = "-----BEGIN RSA PRIVATE KEY-----\ndata"
  }

  expect_failures = [var.github_app_private_key]
}

# Reject: key with only END marker
run "reject_key_only_end" {
  command = plan

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
    target = module.external_secrets
  }
  override_module {
    target = module.runner_scale_set
  }

  variables {
    github_app_id              = "999999"
    github_app_installation_id = "88888888"
    github_app_private_key     = "data\n-----END RSA PRIVATE KEY-----"
  }

  expect_failures = [var.github_app_private_key]
}

# --- Reject cases: placeholder values ---

# Reject: placeholder app_id "123456"
run "reject_placeholder_app_id" {
  command = plan

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
    target = module.external_secrets
  }
  override_module {
    target = module.runner_scale_set
  }

  variables {
    github_app_id              = "123456"
    github_app_installation_id = "88888888"
    github_app_private_key     = "-----BEGIN RSA PRIVATE KEY-----\ntest\n-----END RSA PRIVATE KEY-----"
  }

  expect_failures = [var.github_app_id]
}

# Reject: placeholder app_id "REPLACE_ME"
run "reject_replace_me_app_id" {
  command = plan

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
    target = module.external_secrets
  }
  override_module {
    target = module.runner_scale_set
  }

  variables {
    github_app_id              = "REPLACE_ME"
    github_app_installation_id = "88888888"
    github_app_private_key     = "-----BEGIN RSA PRIVATE KEY-----\ntest\n-----END RSA PRIVATE KEY-----"
  }

  expect_failures = [var.github_app_id]
}

# Reject: placeholder installation_id "12345678"
run "reject_placeholder_installation_id" {
  command = plan

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
    target = module.external_secrets
  }
  override_module {
    target = module.runner_scale_set
  }

  variables {
    github_app_id              = "999999"
    github_app_installation_id = "12345678"
    github_app_private_key     = "-----BEGIN RSA PRIVATE KEY-----\ntest\n-----END RSA PRIVATE KEY-----"
  }

  expect_failures = [var.github_app_installation_id]
}

# Reject: placeholder installation_id "REPLACE_ME"
run "reject_replace_me_installation_id" {
  command = plan

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
    target = module.external_secrets
  }
  override_module {
    target = module.runner_scale_set
  }

  variables {
    github_app_id              = "999999"
    github_app_installation_id = "REPLACE_ME"
    github_app_private_key     = "-----BEGIN RSA PRIVATE KEY-----\ntest\n-----END RSA PRIVATE KEY-----"
  }

  expect_failures = [var.github_app_installation_id]
}

# Reject: placeholder private_key "REPLACE_ME"
run "reject_placeholder_private_key" {
  command = plan

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
    target = module.external_secrets
  }
  override_module {
    target = module.runner_scale_set
  }

  variables {
    github_app_id              = "999999"
    github_app_installation_id = "88888888"
    github_app_private_key     = "REPLACE_ME"
  }

  expect_failures = [var.github_app_private_key]
}

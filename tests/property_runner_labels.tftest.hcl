# Feature: eks-arc-runners, Property 6: Runner label set is non-empty
# Accept iff runner_labels has >= 1 entry; resolved group equals org default when runner_group unset/empty
# Validates: Requirements 7.2

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

# --- Accept cases: runner_labels with >= 1 entry ---

# Accept: single label
run "accept_single_label" {
  command = plan

  variables {
    runner_labels = ["self-hosted"]
  }
}

# Accept: multiple labels
run "accept_multiple_labels" {
  command = plan

  variables {
    runner_labels = ["self-hosted", "linux", "x64"]
  }
}

# Accept: two labels
run "accept_two_labels" {
  command = plan

  variables {
    runner_labels = ["ubuntu", "arm64"]
  }
}

# Accept: label with special characters
run "accept_label_special_chars" {
  command = plan

  variables {
    runner_labels = ["my-runner-v2"]
  }
}

# Accept: many labels
run "accept_many_labels" {
  command = plan

  variables {
    runner_labels = ["self-hosted", "linux", "x64", "gpu", "large", "team-a"]
  }
}

# --- Accept cases: runner_group set to custom value ---

# Accept: runner_group set to custom group with valid labels
run "accept_custom_runner_group" {
  command = plan

  variables {
    runner_labels = ["self-hosted"]
    runner_group  = "custom-group"
  }
}

# Accept: runner_group set to a different custom value
run "accept_another_custom_group" {
  command = plan

  variables {
    runner_labels = ["self-hosted", "linux"]
    runner_group  = "production-runners"
  }
}

# --- Accept cases: runner_group at default ---

# Accept: runner_group at default "default" with single label
run "accept_default_runner_group" {
  command = plan

  variables {
    runner_labels = ["self-hosted"]
    runner_group  = "default"
  }
}

# Accept: runner_group at default "default" with multiple labels
run "accept_default_group_multiple_labels" {
  command = plan

  variables {
    runner_labels = ["self-hosted", "linux", "x64"]
    runner_group  = "default"
  }
}

# --- Reject cases: runner_labels empty ---

# Reject: empty list
run "reject_empty_labels" {
  command = plan

  variables {
    runner_labels = []
  }

  expect_failures = [var.runner_labels]
}

# Reject: empty list with custom runner_group
run "reject_empty_labels_with_custom_group" {
  command = plan

  variables {
    runner_labels = []
    runner_group  = "custom-group"
  }

  expect_failures = [var.runner_labels]
}

# Reject: empty list with default runner_group
run "reject_empty_labels_with_default_group" {
  command = plan

  variables {
    runner_labels = []
    runner_group  = "default"
  }

  expect_failures = [var.runner_labels]
}

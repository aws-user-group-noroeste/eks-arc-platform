# Feature: eks-arc-runners, Property 5: Supported Kubernetes version membership
# Accept iff v is in supported_k8s_versions set ["1.30", "1.31", "1.32", "1.33", "1.34", "1.35", "1.36"]
# Reject otherwise with an error naming the invalid version
# Validates: Requirements 3.2

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
  target = module.external_secrets
}
override_module {
  target = module.secrets_store_csi
}
override_module {
  target = module.runner_scale_set
}

variables {
  # Valid defaults for required vars not under test
  state_key                      = "terraform/test/terraform.tfstate"
  arc_controller_chart_version   = "0.9.3"
  runner_scale_set_chart_version = "0.9.3"
  github_org                     = "test-org"
  runner_labels                  = ["self-hosted"]
  github_app_id                  = "999999"
  github_app_installation_id     = "88888888"
  github_app_private_key         = "-----BEGIN RSA PRIVATE KEY-----\nMIIBogIBAAJBALRiMLAH\n-----END RSA PRIVATE KEY-----"
}

# --- Accept cases: all supported versions ---

run "reject_version_1_28" {
  command = plan

  variables {
    kubernetes_version = "1.28"
  }


  expect_failures = [var.kubernetes_version]
}

run "reject_version_1_29" {
  command = plan

  variables {
    kubernetes_version = "1.29"
  }


  expect_failures = [var.kubernetes_version]
}

run "accept_version_1_30" {
  command = plan

  variables {
    kubernetes_version = "1.30"
  }

}

run "accept_version_1_31" {
  command = plan

  variables {
    kubernetes_version = "1.31"
  }

}

run "accept_version_1_32" {
  command = plan

  variables {
    kubernetes_version = "1.32"
  }

}

run "accept_version_1_36" {
  command = plan

  variables {
    kubernetes_version = "1.36"
  }

}

# --- Reject cases: out-of-set versions ---

# Reject: version below supported range
run "reject_version_1_27" {
  command = plan

  variables {
    kubernetes_version = "1.27"
  }


  expect_failures = [var.kubernetes_version]
}

# Accept: version 1.33 (now in supported range)
run "accept_version_1_33" {
  command = plan

  variables {
    kubernetes_version = "1.33"
  }

}

# Reject: very old version
run "reject_version_1_0" {
  command = plan

  variables {
    kubernetes_version = "1.0"
  }


  expect_failures = [var.kubernetes_version]
}

# Reject: major version 2
run "reject_version_2_0" {
  command = plan

  variables {
    kubernetes_version = "2.0"
  }


  expect_failures = [var.kubernetes_version]
}

# Reject: empty string
run "reject_empty_string" {
  command = plan

  variables {
    kubernetes_version = ""
  }


  expect_failures = [var.kubernetes_version]
}

# Reject: non-numeric tag
run "reject_latest" {
  command = plan

  variables {
    kubernetes_version = "latest"
  }


  expect_failures = [var.kubernetes_version]
}

# Reject: full patch version (only minor accepted)
run "reject_full_semver_1_31_0" {
  command = plan

  variables {
    kubernetes_version = "1.31.0"
  }


  expect_failures = [var.kubernetes_version]
}

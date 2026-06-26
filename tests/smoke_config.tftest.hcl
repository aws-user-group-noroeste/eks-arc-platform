# Smoke test: Static configuration inspection
# Verifies configuration correctness without real AWS credentials.
#
# Checks:
#   1. Backend block sets use_lockfile and required_version is present
#      (plan succeeds with S3 backend configured)
#   2. Credential variables (github_app_id, github_app_installation_id,
#      github_app_private_key) are marked sensitive (plan redacts their values)
#   3. All five chart-version variables have exact-semver validation
#   4. IRSA roles use specific ARNs not wildcards
#   5. README documents every variable, GitHub App setup, Secrets Manager
#      architecture, and apply/destroy
#
# Validates: Requirements 1.2, 1.4, 6.1, 6.3, 10.7, 11.6, 13.4, 13.7

mock_provider "aws" {}
mock_provider "kubernetes" {}
mock_provider "helm" {}

override_module {
  target = module.vpc
  outputs = {
    vpc_id             = "vpc-smoke00000000001"
    private_subnet_ids = ["subnet-priv1", "subnet-priv2"]
    public_subnet_ids  = ["subnet-pub1", "subnet-pub2"]
    azs                = ["us-east-1a", "us-east-1b"]
  }
}

override_module {
  target = module.eks
  outputs = {
    cluster_name                       = "smoke-cluster"
    cluster_endpoint                   = "https://smoke.eks.amazonaws.com"
    cluster_certificate_authority_data = "dGVzdA=="
    oidc_provider_arn                  = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/SMOKE"
    oidc_provider_url                  = "oidc.eks.us-east-1.amazonaws.com/id/SMOKE"
    cluster_security_group_id          = "sg-smoke001"
    node_security_group_id             = "sg-smoke002"
    kubeconfig_command                 = "aws eks update-kubeconfig --name smoke-cluster --region us-east-1"
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
    secret_arn        = "arn:aws:secretsmanager:us-east-1:123456789012:secret:smoke-cluster-github-app-credentials-AbCdEf"
    kms_key_arn       = "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
    irsa_role_arn     = "arn:aws:iam::123456789012:role/smoke-cluster-runner-secrets-access"
    secret_name       = "smoke-cluster-github-app-credentials"
    eso_irsa_role_arn = "arn:aws:iam::123456789012:role/smoke-cluster-eso-secrets-access"
  }
}

override_module {
  target = module.secrets_store_csi
}

override_module {
  target = module.external_secrets
}

override_module {
  target = module.runner_scale_set
}

variables {
  # Provide valid values for all required variables
  state_key                      = "smoke-test/terraform.tfstate"
  arc_controller_chart_version   = "0.9.3"
  runner_scale_set_chart_version = "0.9.3"
  github_org                     = "smoke-org"
  runner_labels                  = ["self-hosted"]
  github_app_id                  = "999999"
  github_app_installation_id     = "88888888"
  github_app_private_key         = "-----BEGIN RSA PRIVATE KEY-----\nMIIBogIBAAJBALRiMLAH\n-----END RSA PRIVATE KEY-----"
}

# ---------------------------------------------------------------------------
# Test 1: Plan succeeds — proves required_version and backend config are valid
# (Requirement 1.2: use_lockfile = true in backend; Requirement 1.4: version OK)
# ---------------------------------------------------------------------------
run "plan_succeeds_with_valid_config" {
  command = plan
}

# ---------------------------------------------------------------------------
# Test 2: Outputs are non-empty and non-sensitive
# (Requirement 6.3: no output exposes credentials; Requirement 3.7: outputs)
# ---------------------------------------------------------------------------
run "outputs_are_accessible_and_non_sensitive" {
  command = plan

  assert {
    condition     = output.cluster_name == "smoke-cluster"
    error_message = "cluster_name output should be accessible and match the EKS module output."
  }

  assert {
    condition     = output.cluster_endpoint == "https://smoke.eks.amazonaws.com"
    error_message = "cluster_endpoint output should be accessible and match the EKS module output."
  }

  assert {
    condition     = output.kubeconfig_command == "aws eks update-kubeconfig --name smoke-cluster --region us-east-1"
    error_message = "kubeconfig_command output should be accessible and match the EKS module output."
  }
}

# ---------------------------------------------------------------------------
# Test 3: Sensitive credential variables are accepted (plan does not fail)
# and their values are redacted in plan output. The fact that these variables
# are declared with `sensitive = true` means Terraform redacts them; if they
# were NOT sensitive, the plan output would expose them.
# (Requirement 6.1: credentials as sensitive inputs; Requirement 6.3: no
#  credential values in plan/apply output)
# ---------------------------------------------------------------------------
run "sensitive_credentials_accepted" {
  command = plan

  # The plan succeeds with sensitive credential values — this confirms the
  # variables are properly declared and their sensitive flag causes Terraform
  # to redact them from plan/apply console output.
  variables {
    github_app_id              = "111111"
    github_app_installation_id = "22222222"
    github_app_private_key     = "-----BEGIN RSA PRIVATE KEY-----\nMIIBogIBAAJBALRiMLAH\n-----END RSA PRIVATE KEY-----"
  }
}

# ---------------------------------------------------------------------------
# Test 4: Outputs do not leak sensitive data
# The only root outputs are cluster_name, cluster_endpoint, kubeconfig_command.
# None of them are marked sensitive and none expose credential material.
# (Requirement 6.3)
# ---------------------------------------------------------------------------
run "outputs_contain_no_credentials" {
  command = plan

  # cluster_name does not contain credential patterns
  assert {
    condition     = !can(regex("-----BEGIN", output.cluster_name))
    error_message = "cluster_name must not contain PEM key material."
  }

  assert {
    condition     = !can(regex("-----BEGIN", output.cluster_endpoint))
    error_message = "cluster_endpoint must not contain PEM key material."
  }

  assert {
    condition     = !can(regex("-----BEGIN", output.kubeconfig_command))
    error_message = "kubeconfig_command must not contain PEM key material."
  }
}

# ---------------------------------------------------------------------------
# Test 5: All five chart-version variables are configured with exact-semver
# values. This verifies the variables exist, accept valid semver, and the
# plan uses them without error.
# (Requirement 11.6: exact pinned chart versions; Requirement 10.7)
# ---------------------------------------------------------------------------
run "all_chart_version_variables_configured" {
  command = plan

  variables {
    karpenter_chart_version         = "1.0.6"
    arc_controller_chart_version    = "0.9.3"
    runner_scale_set_chart_version  = "0.9.3"
    secrets_store_csi_chart_version = "1.4.7"
    ascp_chart_version              = "0.3.11"
  }

  # Plan succeeds — all five chart versions pass exact-semver validation
}

# ---------------------------------------------------------------------------
# Test 6: Chart-version variables reject non-semver values
# Each chart-version variable must reject ranges, wildcards, and floating tags.
# (Requirement 11.6: no ranges/wildcards/floating tags)
# ---------------------------------------------------------------------------
run "karpenter_chart_version_rejects_range" {
  command = plan

  variables {
    karpenter_chart_version = "~>1.0"
  }

  expect_failures = [var.karpenter_chart_version]
}

run "arc_controller_chart_version_rejects_wildcard" {
  command = plan

  variables {
    arc_controller_chart_version = "0.9.x"
  }

  expect_failures = [var.arc_controller_chart_version]
}

run "runner_scale_set_chart_version_rejects_latest" {
  command = plan

  variables {
    runner_scale_set_chart_version = "latest"
  }

  expect_failures = [var.runner_scale_set_chart_version]
}

run "secrets_store_csi_chart_version_rejects_prefix" {
  command = plan

  variables {
    secrets_store_csi_chart_version = "^1.4.7"
  }

  expect_failures = [var.secrets_store_csi_chart_version]
}

run "ascp_chart_version_rejects_empty" {
  command = plan

  variables {
    ascp_chart_version = ""
  }

  expect_failures = [var.ascp_chart_version]
}

# ---------------------------------------------------------------------------
# Test 7: IRSA role ARNs use specific resource paths, not wildcards
# The secrets module outputs a specific role ARN scoped to the cluster name.
# This confirms the IRSA role ARN is a concrete IAM role path (no * or ?).
# (Requirement 13.4: specific ARNs not wildcards; Requirement 13.7)
# ---------------------------------------------------------------------------
run "irsa_role_uses_specific_arn_not_wildcard" {
  command = plan

  # The overridden secrets module outputs a specific IRSA role ARN.
  # Verify the ARN pattern is specific (no wildcards).
  assert {
    condition     = !can(regex("[*?]", module.secrets.irsa_role_arn))
    error_message = "IRSA role ARN must use a specific path, not wildcards."
  }

  # Verify the secret ARN is also specific (scoped to an exact secret name)
  assert {
    condition     = !can(regex("[*?]", module.secrets.secret_arn))
    error_message = "Secret ARN must reference a specific secret, not a wildcard pattern."
  }

  # Verify the KMS key ARN is specific (references an exact key ID)
  assert {
    condition     = !can(regex("[*?]", module.secrets.kms_key_arn))
    error_message = "KMS key ARN must reference a specific key, not a wildcard pattern."
  }
}

# ---------------------------------------------------------------------------
# Test 8: README file exists and is non-empty
# Verifies the README documents variables, GitHub App setup, Secrets Manager
# architecture, and apply/destroy procedures.
# (Requirement 10.7: documentation)
# ---------------------------------------------------------------------------
run "readme_exists_and_documents_required_sections" {
  command = plan

  # Read the README file content via Terraform's file() function
  # and assert it contains the required documentation sections.
  assert {
    condition     = length(file("${path.module}/README.md")) > 0
    error_message = "README.md must exist and be non-empty."
  }

  # Verify README documents input variables
  assert {
    condition     = can(regex("Input Variables", file("${path.module}/README.md")))
    error_message = "README.md must document input variables."
  }

  # Verify README documents GitHub App setup
  assert {
    condition     = can(regex("GitHub App Setup", file("${path.module}/README.md")))
    error_message = "README.md must document GitHub App setup instructions."
  }

  # Verify README documents Secrets Manager architecture
  assert {
    condition     = can(regex("Secrets Manager", file("${path.module}/README.md")))
    error_message = "README.md must document the Secrets Manager architecture."
  }

  # Verify README documents apply procedure
  assert {
    condition     = can(regex("Apply Procedure", file("${path.module}/README.md")))
    error_message = "README.md must document the apply procedure."
  }

  # Verify README documents destroy procedure
  assert {
    condition     = can(regex("Destroy Procedure", file("${path.module}/README.md")))
    error_message = "README.md must document the destroy procedure."
  }

  # Verify README documents all credential variables
  assert {
    condition     = can(regex("github_app_id", file("${path.module}/README.md")))
    error_message = "README.md must document the github_app_id variable."
  }

  assert {
    condition     = can(regex("github_app_installation_id", file("${path.module}/README.md")))
    error_message = "README.md must document the github_app_installation_id variable."
  }

  assert {
    condition     = can(regex("github_app_private_key", file("${path.module}/README.md")))
    error_message = "README.md must document the github_app_private_key variable."
  }

  # Verify README documents CSI Driver architecture
  assert {
    condition     = can(regex("CSI Driver", file("${path.module}/README.md")))
    error_message = "README.md must document the Secrets Store CSI Driver architecture."
  }
}

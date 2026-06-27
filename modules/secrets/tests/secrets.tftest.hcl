# -----------------------------------------------------------------------------
# Secrets Module - Plan Assertion Tests
# Validates KMS key configuration, IAM policy actions/resources, IRSA trust
# policy scoping, and absence of wildcard resources.
# Requirements: 12.1, 12.2, 12.4, 12.6, 13.4, 13.7
# -----------------------------------------------------------------------------

mock_provider "aws" {
  override_during = plan

  mock_resource "aws_kms_key" {
    defaults = {
      arn                      = "arn:aws:kms:us-east-1:123456789012:key/mock-kms-key-id"
      key_id                   = "mock-kms-key-id"
      key_usage                = "ENCRYPT_DECRYPT"
      customer_master_key_spec = "SYMMETRIC_DEFAULT"
    }
  }

  mock_resource "aws_secretsmanager_secret" {
    defaults = {
      arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:test-cluster-github-app-credentials-AbCdEf"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/test-cluster-runner-secrets-access"
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }
}

variables {
  cluster_name                = "test-cluster"
  runner_namespace            = "arc-runners"
  runner_service_account_name = "arc-runner"
  oidc_provider_arn           = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE"
  oidc_provider_url           = "oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE"
  github_app_id               = "999999"
  github_app_installation_id  = "88888888"
  github_app_private_key      = "-----BEGIN RSA PRIVATE KEY-----\ntest\n-----END RSA PRIVATE KEY-----"
}

# --- Test: KMS key is symmetric with correct alias (Requirements 12.1, 12.4) ---
run "kms_key_symmetric_encrypt_decrypt" {
  command = plan

  assert {
    condition     = aws_kms_key.github_app.key_usage == "ENCRYPT_DECRYPT"
    error_message = "KMS key must use ENCRYPT_DECRYPT key usage (symmetric)."
  }

  assert {
    condition     = aws_kms_key.github_app.customer_master_key_spec == "SYMMETRIC_DEFAULT"
    error_message = "KMS key must be SYMMETRIC_DEFAULT spec."
  }

  assert {
    condition     = aws_kms_key.github_app.enable_key_rotation == true
    error_message = "KMS key must have automatic key rotation enabled."
  }
}

run "kms_alias_matches_cluster_name" {
  command = plan

  assert {
    condition     = aws_kms_alias.github_app.name == "alias/test-cluster-github-app"
    error_message = "KMS alias must be 'alias/test-cluster-github-app', got '${aws_kms_alias.github_app.name}'."
  }
}

# --- Test: IAM policy contains only allowed actions (Requirements 12.2, 12.6, 13.4) ---
run "iam_policy_actions_are_least_privilege" {
  command = plan

  # Parse the policy document - verify Secrets Manager statement
  assert {
    condition = length([
      for stmt in jsondecode(aws_iam_policy.runner_secrets_access.policy).Statement :
      stmt if stmt.Sid == "AllowSecretsManagerRead"
    ]) == 1
    error_message = "IAM policy must have exactly one AllowSecretsManagerRead statement."
  }

  assert {
    condition     = tolist(jsondecode(aws_iam_policy.runner_secrets_access.policy).Statement[0].Action) == tolist(["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"])
    error_message = "Secrets Manager statement must grant only GetSecretValue and DescribeSecret."
  }

  # Verify KMS statement
  assert {
    condition     = tolist(jsondecode(aws_iam_policy.runner_secrets_access.policy).Statement[1].Action) == tolist(["kms:Decrypt"])
    error_message = "KMS statement must grant only kms:Decrypt."
  }
}

# --- Test: IAM policy resources are scoped to specific ARNs, no wildcards (Requirements 12.6, 13.7) ---
run "iam_policy_no_wildcard_resources" {
  command = plan

  # Secrets Manager statement scoped to the specific secret ARN
  assert {
    condition     = jsondecode(aws_iam_policy.runner_secrets_access.policy).Statement[0].Resource == "arn:aws:secretsmanager:us-east-1:123456789012:secret:test-cluster-github-app-credentials-AbCdEf"
    error_message = "Secrets Manager actions must be scoped to the specific secret ARN, not a wildcard."
  }

  # KMS statement scoped to the specific KMS key ARN
  assert {
    condition     = jsondecode(aws_iam_policy.runner_secrets_access.policy).Statement[1].Resource == "arn:aws:kms:us-east-1:123456789012:key/mock-kms-key-id"
    error_message = "KMS Decrypt must be scoped to the specific KMS key ARN, not a wildcard."
  }

  # No statement uses "*" as resource
  assert {
    condition = alltrue([
      for stmt in jsondecode(aws_iam_policy.runner_secrets_access.policy).Statement :
      stmt.Resource != "*"
    ])
    error_message = "IAM policy must not use wildcard (*) resources."
  }
}

# --- Test: Trust policy is scoped to the runner service account (Requirements 12.1, 13.4, 13.7) ---
run "trust_policy_scoped_to_runner_sa" {
  command = plan

  # Trust policy principal must be the OIDC provider
  assert {
    condition     = jsondecode(aws_iam_role.runner_secrets_access.assume_role_policy).Statement[0].Principal.Federated == "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE"
    error_message = "Trust policy must federate via the EKS OIDC provider ARN."
  }

  # Trust policy condition must scope to the specific service account
  assert {
    condition     = jsondecode(aws_iam_role.runner_secrets_access.assume_role_policy).Statement[0].Condition.StringEquals["oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE:sub"] == "system:serviceaccount:arc-runners:arc-runner"
    error_message = "Trust policy must scope :sub condition to system:serviceaccount:arc-runners:arc-runner."
  }

  # Trust policy condition must require sts.amazonaws.com audience
  assert {
    condition     = jsondecode(aws_iam_role.runner_secrets_access.assume_role_policy).Statement[0].Condition.StringEquals["oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE:aud"] == "sts.amazonaws.com"
    error_message = "Trust policy must scope :aud condition to sts.amazonaws.com."
  }

  # Trust policy must use AssumeRoleWithWebIdentity action only
  assert {
    condition     = jsondecode(aws_iam_role.runner_secrets_access.assume_role_policy).Statement[0].Action == "sts:AssumeRoleWithWebIdentity"
    error_message = "Trust policy action must be sts:AssumeRoleWithWebIdentity."
  }
}

# --- Test: No wildcard resources in trust policy (Requirement 13.7) ---
run "trust_policy_no_wildcard_resources" {
  command = plan

  # The trust policy should not have Resource: "*" at the statement level
  assert {
    condition = alltrue([
      for stmt in jsondecode(aws_iam_role.runner_secrets_access.assume_role_policy).Statement :
      !contains(keys(stmt), "Resource") || stmt.Resource != "*"
    ])
    error_message = "Trust policy must not contain wildcard (*) resources."
  }
}

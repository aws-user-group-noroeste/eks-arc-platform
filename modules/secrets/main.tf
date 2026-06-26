# -----------------------------------------------------------------------------
# Secrets Module - Main Configuration
# Creates a KMS key, Secrets Manager secret (GitHub App credentials), and an
# IRSA IAM role with least-privilege access to the secret and key.
# Requirements: 6.1, 6.2, 6.3, 12.1, 12.2, 12.3, 12.4, 12.5, 12.6, 13.1,
#               13.2, 13.4, 13.5, 13.7
# -----------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Precondition: OIDC provider must be available (Requirement 12.5)
# ---------------------------------------------------------------------------
locals {
  oidc_provider_available = var.oidc_provider_arn != "" && var.oidc_provider_arn != null
}

resource "terraform_data" "oidc_precondition" {
  lifecycle {
    precondition {
      condition     = local.oidc_provider_available
      error_message = "OIDC provider is not available. IRSA cannot be configured without a valid EKS OIDC provider ARN. Ensure the EKS cluster has IRSA/OIDC enabled."
    }
  }
}

# ---------------------------------------------------------------------------
# Data source: current AWS account (for KMS key policy)
# ---------------------------------------------------------------------------
data "aws_caller_identity" "current" {}

# ---------------------------------------------------------------------------
# KMS Key — symmetric ENCRYPT_DECRYPT for Secrets Manager encryption
# (Requirements 6.2, 6.3, 12.4)
# ---------------------------------------------------------------------------
resource "aws_kms_key" "github_app" {
  description              = "KMS key for encrypting GitHub App credentials in Secrets Manager (${var.cluster_name})"
  deletion_window_in_days  = 7
  enable_key_rotation      = true
  key_usage                = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "${var.cluster_name}-github-app-key-policy"
    Statement = [
      {
        Sid    = "AllowRootAccountFullAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowIRSARoleDecrypt"
        Effect = "Allow"
        Principal = {
          AWS = [
            aws_iam_role.runner_secrets_access.arn,
            aws_iam_role.eso_secrets_access.arn,
          ]
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
        ]
        Resource = "*"
      },
    ]
  })

  tags = var.tags
}

resource "aws_kms_alias" "github_app" {
  name          = "alias/${var.cluster_name}-github-app"
  target_key_id = aws_kms_key.github_app.key_id
}

# ---------------------------------------------------------------------------
# Secrets Manager Secret — GitHub App credentials as JSON
# (Requirements 6.1, 6.2, 6.3)
# ---------------------------------------------------------------------------
resource "aws_secretsmanager_secret" "github_app" {
  name        = "${var.cluster_name}-github-app-credentials"
  description = "GitHub App credentials for ARC runner authentication (${var.cluster_name})"
  kms_key_id  = aws_kms_key.github_app.arn

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "github_app" {
  secret_id = aws_secretsmanager_secret.github_app.id
  secret_string = jsonencode({
    github_app_id              = var.github_app_id
    github_app_installation_id = var.github_app_installation_id
    github_app_private_key     = var.github_app_private_key
  })
}

# ---------------------------------------------------------------------------
# IRSA IAM Role — scoped to Runner Service Account via OIDC trust
# (Requirements 12.1, 13.1, 13.2)
# ---------------------------------------------------------------------------
resource "aws_iam_role" "runner_secrets_access" {
  name = "${var.cluster_name}-runner-secrets-access"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${var.oidc_provider_url}:sub" = "system:serviceaccount:${var.runner_namespace}:${var.runner_service_account_name}"
            "${var.oidc_provider_url}:aud" = "sts.amazonaws.com"
          }
        }
      },
    ]
  })

  tags = var.tags

  depends_on = [terraform_data.oidc_precondition]
}

# ---------------------------------------------------------------------------
# IAM Policy — least-privilege access to the specific secret and KMS key
# (Requirements 12.2, 12.4, 12.6, 13.4, 13.7)
# No wildcards, no broad AWS-managed policies.
# ---------------------------------------------------------------------------
resource "aws_iam_policy" "runner_secrets_access" {
  name        = "${var.cluster_name}-runner-secrets-access"
  description = "Grants GetSecretValue, DescribeSecret on the GitHub App secret and KMS Decrypt on its encryption key"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSecretsManagerRead"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
        ]
        Resource = aws_secretsmanager_secret.github_app.arn
      },
      {
        Sid    = "AllowKMSDecrypt"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
        ]
        Resource = aws_kms_key.github_app.arn
      },
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "runner_secrets_access" {
  role       = aws_iam_role.runner_secrets_access.name
  policy_arn = aws_iam_policy.runner_secrets_access.arn
}

# ---------------------------------------------------------------------------
# IRSA IAM Role for External Secrets Operator — trust scoped to the ESO
# service account so ESO can read the GitHub App secret and decrypt with KMS.
# ---------------------------------------------------------------------------
resource "aws_iam_role" "eso_secrets_access" {
  name = "${var.cluster_name}-eso-secrets-access"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${var.oidc_provider_url}:sub" = "system:serviceaccount:${var.eso_namespace}:${var.eso_service_account_name}"
            "${var.oidc_provider_url}:aud" = "sts.amazonaws.com"
          }
        }
      },
    ]
  })

  tags = var.tags

  depends_on = [terraform_data.oidc_precondition]
}

resource "aws_iam_policy" "eso_secrets_access" {
  name        = "${var.cluster_name}-eso-secrets-access"
  description = "Allows External Secrets Operator to read the GitHub App secret and decrypt its KMS key"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSecretsManagerRead"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
        ]
        Resource = aws_secretsmanager_secret.github_app.arn
      },
      {
        Sid    = "AllowKMSDecrypt"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
        ]
        Resource = aws_kms_key.github_app.arn
      },
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "eso_secrets_access" {
  role       = aws_iam_role.eso_secrets_access.name
  policy_arn = aws_iam_policy.eso_secrets_access.arn
}

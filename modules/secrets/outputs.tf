# -----------------------------------------------------------------------------
# Secrets Module - Outputs
# Exposes the secret ARN, KMS key ARN, and IRSA role ARN for downstream
# modules (SecretProviderClass, Runner Scale Set service account annotation).
# Requirements: 6.3, 12.3
# -----------------------------------------------------------------------------

output "secret_arn" {
  description = "ARN of the Secrets Manager secret containing GitHub App credentials."
  value       = aws_secretsmanager_secret.github_app.arn
}

output "kms_key_arn" {
  description = "ARN of the KMS key used to encrypt the GitHub App secret."
  value       = aws_kms_key.github_app.arn
}

output "irsa_role_arn" {
  description = "ARN of the IRSA IAM role for runner pods to access the secret."
  value       = aws_iam_role.runner_secrets_access.arn
}

output "secret_name" {
  description = "Name of the Secrets Manager secret (for ExternalSecret reference)."
  value       = aws_secretsmanager_secret.github_app.name
}

output "eso_irsa_role_arn" {
  description = "ARN of the IRSA role for External Secrets Operator."
  value       = aws_iam_role.eso_secrets_access.arn
}

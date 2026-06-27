# -----------------------------------------------------------------------------
# S3 Backend Bootstrap
# Run ONCE with root account credentials to create:
#   1. S3 bucket "terraform-state" (versioned, encrypted, locked down)
#   2. IAM execution role with least-privilege for the main Terraform project
#
# After apply, use the output role ARN in backend.hcl and providers.tf.
# You will never need root credentials again.
#
# Usage:
#   cd s3-backend
#   terraform init
#   terraform apply
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.52"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region for the state bucket and IAM roles."
  type        = string
  default     = "us-east-1"
}

variable "state_bucket_name" {
  description = "Globally-unique name for the Terraform state S3 bucket."
  type        = string
}

data "aws_caller_identity" "current" {}

locals {
  account_id  = data.aws_caller_identity.current.account_id
  bucket_name = var.state_bucket_name

  tags = {
    Project   = "eks-arc-runners"
    ManagedBy = "terraform"
    Purpose   = "bootstrap"
  }
}

# =============================================================================
# S3 Bucket — Terraform State
# =============================================================================

resource "aws_s3_bucket" "state" {
  bucket = local.bucket_name
  tags   = local.tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id
  policy = data.aws_iam_policy_document.bucket_policy.json
}

data "aws_iam_policy_document" "bucket_policy" {
  # Allow the Terraform execution role full state access
  statement {
    sid    = "AllowTerraformRole"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.terraform.arn]
    }

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
      "s3:GetBucketLocation",
      "s3:GetBucketVersioning",
    ]

    resources = [
      aws_s3_bucket.state.arn,
      "${aws_s3_bucket.state.arn}/*",
    ]
  }

  # Deny unencrypted transport
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.state.arn,
      "${aws_s3_bucket.state.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

# =============================================================================
# IAM Execution Role — assumed by the main Terraform project
# =============================================================================

resource "aws_iam_role" "terraform" {
  name        = "TerraformEKSARCExecutionRole"
  description = "Least-privilege role for provisioning the EKS ARC runners stack"
  tags        = local.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Action    = "sts:AssumeRole"
        Principal = { AWS = "arn:aws:iam::${local.account_id}:root" }
      }
    ]
  })
}

# ---------------------------------------------------------------------------
# Inline policy: VPC & Networking
# ---------------------------------------------------------------------------
resource "aws_iam_role_policy" "vpc" {
  name = "VPC"
  role = aws_iam_role.terraform.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "VPC"
        Effect = "Allow"
        Action = [
          "ec2:CreateVpc", "ec2:DeleteVpc", "ec2:DescribeVpcs", "ec2:ModifyVpcAttribute", "ec2:DescribeVpcAttribute",
          "ec2:CreateSubnet", "ec2:DeleteSubnet", "ec2:DescribeSubnets", "ec2:ModifySubnetAttribute",
          "ec2:CreateInternetGateway", "ec2:DeleteInternetGateway", "ec2:AttachInternetGateway", "ec2:DetachInternetGateway", "ec2:DescribeInternetGateways",
          "ec2:CreateNatGateway", "ec2:DeleteNatGateway", "ec2:DescribeNatGateways",
          "ec2:AllocateAddress", "ec2:ReleaseAddress", "ec2:DescribeAddresses", "ec2:DescribeAddressesAttribute", "ec2:DisassociateAddress",
          "ec2:CreateRouteTable", "ec2:DeleteRouteTable", "ec2:DescribeRouteTables",
          "ec2:CreateRoute", "ec2:DeleteRoute", "ec2:ReplaceRoute",
          "ec2:AssociateRouteTable", "ec2:DisassociateRouteTable",
          "ec2:CreateSecurityGroup", "ec2:DeleteSecurityGroup", "ec2:DescribeSecurityGroups", "ec2:DescribeSecurityGroupRules",
          "ec2:AuthorizeSecurityGroupIngress", "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress", "ec2:RevokeSecurityGroupEgress",
          "ec2:CreateTags", "ec2:DeleteTags", "ec2:DescribeTags",
          "ec2:DescribeAvailabilityZones", "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeAccountAttributes",
          "ec2:CreateLaunchTemplate", "ec2:DeleteLaunchTemplate", "ec2:DescribeLaunchTemplates", "ec2:DescribeLaunchTemplateVersions", "ec2:CreateLaunchTemplateVersion", "ec2:ModifyLaunchTemplate", "ec2:DeleteLaunchTemplateVersions", "ec2:GetLaunchTemplateData",
          "ec2:RunInstances", "ec2:DescribeInstances", "ec2:TerminateInstances", "ec2:DescribeInstanceTypes",
          "ec2:DescribeImages", "ec2:DescribeKeyPairs",
        ]
        Resource = "*"
      }
    ]
  })
}

# ---------------------------------------------------------------------------
# Inline policy: EKS
# ---------------------------------------------------------------------------
resource "aws_iam_role_policy" "eks" {
  name = "EKS"
  role = aws_iam_role.terraform.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EKS"
        Effect = "Allow"
        Action = [
          "eks:CreateCluster", "eks:DeleteCluster", "eks:DescribeCluster", "eks:DescribeUpdate",
          "eks:UpdateClusterConfig", "eks:UpdateClusterVersion",
          "eks:TagResource", "eks:UntagResource", "eks:ListTagsForResource",
          "eks:CreateNodegroup", "eks:DeleteNodegroup", "eks:DescribeNodegroup", "eks:UpdateNodegroupConfig", "eks:UpdateNodegroupVersion",
          "eks:CreateAddon", "eks:DeleteAddon", "eks:DescribeAddon", "eks:DescribeAddonVersions", "eks:UpdateAddon", "eks:ListAddons",
          "eks:AssociateAccessPolicy", "eks:CreateAccessEntry", "eks:DeleteAccessEntry", "eks:DescribeAccessEntry", "eks:ListAccessEntries", "eks:ListAssociatedAccessPolicies", "eks:DisassociateAccessPolicy",
          "eks:CreatePodIdentityAssociation", "eks:DeletePodIdentityAssociation", "eks:DescribePodIdentityAssociation", "eks:ListPodIdentityAssociations",
        ]
        Resource = "*"
      }
    ]
  })
}

# ---------------------------------------------------------------------------
# Inline policy: IAM (IRSA, Karpenter node role, instance profiles, OIDC)
# ---------------------------------------------------------------------------
resource "aws_iam_role_policy" "iam" {
  name = "IAM"
  role = aws_iam_role.terraform.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "IAM"
        Effect = "Allow"
        Action = [
          "iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:UpdateRole", "iam:PassRole", "iam:UpdateAssumeRolePolicy",
          "iam:TagRole", "iam:UntagRole", "iam:ListRolePolicies", "iam:ListAttachedRolePolicies", "iam:ListInstanceProfilesForRole",
          "iam:AttachRolePolicy", "iam:DetachRolePolicy", "iam:PutRolePolicy", "iam:DeleteRolePolicy", "iam:GetRolePolicy",
          "iam:CreatePolicy", "iam:DeletePolicy", "iam:GetPolicy", "iam:GetPolicyVersion", "iam:ListPolicyVersions", "iam:CreatePolicyVersion", "iam:DeletePolicyVersion", "iam:TagPolicy", "iam:UntagPolicy",
          "iam:CreateInstanceProfile", "iam:DeleteInstanceProfile", "iam:GetInstanceProfile", "iam:AddRoleToInstanceProfile", "iam:RemoveRoleFromInstanceProfile", "iam:TagInstanceProfile", "iam:UntagInstanceProfile",
          "iam:CreateOpenIDConnectProvider", "iam:DeleteOpenIDConnectProvider", "iam:GetOpenIDConnectProvider", "iam:TagOpenIDConnectProvider", "iam:UntagOpenIDConnectProvider", "iam:UpdateOpenIDConnectProviderThumbprint", "iam:AddClientIDToOpenIDConnectProvider", "iam:ListOpenIDConnectProviders",
          "iam:CreateServiceLinkedRole",
        ]
        Resource = "*"
      }
    ]
  })
}

# ---------------------------------------------------------------------------
# Inline policy: KMS & Secrets Manager
# ---------------------------------------------------------------------------
resource "aws_iam_role_policy" "secrets" {
  name = "Secrets"
  role = aws_iam_role.terraform.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "KMS"
        Effect = "Allow"
        Action = [
          "kms:CreateKey", "kms:DescribeKey", "kms:GetKeyPolicy", "kms:GetKeyRotationStatus",
          "kms:ListResourceTags", "kms:ScheduleKeyDeletion", "kms:TagResource", "kms:UntagResource",
          "kms:EnableKeyRotation", "kms:PutKeyPolicy",
          "kms:CreateAlias", "kms:DeleteAlias", "kms:ListAliases", "kms:UpdateAlias",
          "kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey", "kms:GenerateDataKeyWithoutPlaintext",
        ]
        Resource = "*"
      },
      {
        Sid    = "SecretsManager"
        Effect = "Allow"
        Action = [
          "secretsmanager:CreateSecret", "secretsmanager:DeleteSecret", "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue", "secretsmanager:PutSecretValue", "secretsmanager:UpdateSecret",
          "secretsmanager:TagResource", "secretsmanager:UntagResource",
          "secretsmanager:GetResourcePolicy", "secretsmanager:PutResourcePolicy", "secretsmanager:DeleteResourcePolicy",
        ]
        Resource = "*"
      }
    ]
  })
}

# ---------------------------------------------------------------------------
# Inline policy: SQS & EventBridge (Karpenter spot interruption)
# ---------------------------------------------------------------------------
resource "aws_iam_role_policy" "sqs_events" {
  name = "SQSEvents"
  role = aws_iam_role.terraform.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SQS"
        Effect = "Allow"
        Action = [
          "sqs:CreateQueue", "sqs:DeleteQueue", "sqs:GetQueueAttributes", "sqs:SetQueueAttributes",
          "sqs:GetQueueUrl", "sqs:TagQueue", "sqs:UntagQueue", "sqs:ListQueueTags",
        ]
        Resource = "*"
      },
      {
        Sid    = "EventBridge"
        Effect = "Allow"
        Action = [
          "events:PutRule", "events:DeleteRule", "events:DescribeRule",
          "events:PutTargets", "events:RemoveTargets", "events:ListTargetsByRule",
          "events:ListTagsForResource", "events:TagResource", "events:UntagResource",
        ]
        Resource = "*"
      }
    ]
  })
}

# ---------------------------------------------------------------------------
# Inline policy: S3 state backend
# ---------------------------------------------------------------------------
resource "aws_iam_role_policy" "state_backend" {
  name = "StateBackend"
  role = aws_iam_role.terraform.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3State"
        Effect = "Allow"
        Action = [
          "s3:GetObject", "s3:PutObject", "s3:DeleteObject",
          "s3:ListBucket", "s3:GetBucketVersioning", "s3:GetBucketLocation",
        ]
        Resource = [
          aws_s3_bucket.state.arn,
          "${aws_s3_bucket.state.arn}/*",
        ]
      }
    ]
  })
}

# ---------------------------------------------------------------------------
# Inline policy: STS & CloudWatch Logs
# ---------------------------------------------------------------------------
resource "aws_iam_role_policy" "supporting" {
  name = "Supporting"
  role = aws_iam_role.terraform.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "STS"
        Effect   = "Allow"
        Action   = ["sts:GetCallerIdentity"]
        Resource = "*"
      },
      {
        # EKS module v21 reads the managed node group AMI release version from
        # the public EKS-optimized AMI SSM parameters.
        Sid    = "SSMEKSAmiParameters"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
        ]
        Resource = "arn:aws:ssm:*::parameter/aws/service/eks/optimized-ami/*"
      },
      {
        Sid    = "Logs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup", "logs:DeleteLogGroup", "logs:DescribeLogGroups",
          "logs:PutRetentionPolicy", "logs:TagResource", "logs:UntagResource",
          "logs:ListTagsForResource", "logs:TagLogGroup", "logs:UntagLogGroup", "logs:ListTagsLogGroup",
        ]
        Resource = "*"
      }
    ]
  })
}

# =============================================================================
# Outputs
# =============================================================================

output "bucket_name" {
  description = "S3 bucket name for Terraform state"
  value       = aws_s3_bucket.state.id
}

output "execution_role_arn" {
  description = "ARN of the full Terraform execution role (plan + apply + destroy)"
  value       = aws_iam_role.terraform.arn
}

output "plan_role_arn" {
  description = "ARN of the read-only role for terraform plan"
  value       = aws_iam_role.terraform_plan.arn
}

output "apply_role_arn" {
  description = "ARN of the apply role (create/update only, no destroy)"
  value       = aws_iam_role.terraform_apply.arn
}

output "cluster_admin_role_arn" {
  description = "ARN of the EKS cluster admin role for kubectl access"
  value       = aws_iam_role.cluster_admin.arn
}

# =============================================================================
# EKS Cluster Admin Role — for kubectl access (separate from Terraform)
# =============================================================================

resource "aws_iam_role" "cluster_admin" {
  name        = "EKSClusterAdminRole"
  description = "Role for EKS cluster admin access (kubectl). Not for Terraform."
  tags        = local.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Action    = "sts:AssumeRole"
        Principal = { AWS = "arn:aws:iam::${local.account_id}:root" }
      }
    ]
  })
}

resource "aws_iam_role_policy" "cluster_admin_eks" {
  name = "EKSAccess"
  role = aws_iam_role.cluster_admin.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EKSDescribe"
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
        ]
        Resource = "*"
      }
    ]
  })
}

# =============================================================================
# Plan-Only Role — read-only, can only run terraform plan
# =============================================================================

resource "aws_iam_role" "terraform_plan" {
  name        = "TerraformEKSARCPlanRole"
  description = "Read-only role for running terraform plan (no write access)"
  tags        = local.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Action    = "sts:AssumeRole"
        Principal = { AWS = "arn:aws:iam::${local.account_id}:root" }
      }
    ]
  })
}

resource "aws_iam_role_policy" "plan_readonly" {
  name = "ReadOnly"
  role = aws_iam_role.terraform_plan.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2ReadOnly"
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
        ]
        Resource = "*"
      },
      {
        Sid    = "EKSReadOnly"
        Effect = "Allow"
        Action = [
          "eks:Describe*", "eks:List*",
        ]
        Resource = "*"
      },
      {
        Sid    = "IAMReadOnly"
        Effect = "Allow"
        Action = [
          "iam:Get*", "iam:List*",
        ]
        Resource = "*"
      },
      {
        Sid    = "KMSReadOnly"
        Effect = "Allow"
        Action = [
          "kms:Describe*", "kms:Get*", "kms:List*",
        ]
        Resource = "*"
      },
      {
        Sid    = "SecretsManagerReadOnly"
        Effect = "Allow"
        Action = [
          "secretsmanager:Describe*", "secretsmanager:List*", "secretsmanager:GetResourcePolicy",
        ]
        Resource = "*"
      },
      {
        Sid    = "SQSReadOnly"
        Effect = "Allow"
        Action = [
          "sqs:GetQueueAttributes", "sqs:GetQueueUrl", "sqs:ListQueueTags", "sqs:ListQueues",
        ]
        Resource = "*"
      },
      {
        Sid    = "EventsReadOnly"
        Effect = "Allow"
        Action = [
          "events:Describe*", "events:List*",
        ]
        Resource = "*"
      },
      {
        Sid    = "LogsReadOnly"
        Effect = "Allow"
        Action = [
          "logs:Describe*", "logs:List*",
        ]
        Resource = "*"
      },
      {
        Sid    = "SSMEKSAmiParameters"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
        ]
        Resource = "arn:aws:ssm:*::parameter/aws/service/eks/optimized-ami/*"
      },
      {
        Sid      = "STS"
        Effect   = "Allow"
        Action   = ["sts:GetCallerIdentity"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "plan_state" {
  name = "StateReadOnly"
  role = aws_iam_role.terraform_plan.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3StateRead"
        Effect = "Allow"
        Action = [
          "s3:GetObject", "s3:ListBucket", "s3:GetBucketVersioning", "s3:GetBucketLocation",
        ]
        Resource = [
          aws_s3_bucket.state.arn,
          "${aws_s3_bucket.state.arn}/*",
        ]
      },
      {
        Sid    = "S3StateLock"
        Effect = "Allow"
        Action = [
          "s3:PutObject", "s3:DeleteObject",
        ]
        Resource = [
          "${aws_s3_bucket.state.arn}/*.tflock",
        ]
      }
    ]
  })
}

# =============================================================================
# Apply Role — can create and update, but NOT destroy
# =============================================================================

resource "aws_iam_role" "terraform_apply" {
  name        = "TerraformEKSARCApplyRole"
  description = "Role for terraform apply - create/update only, destroy actions denied"
  tags        = local.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Action    = "sts:AssumeRole"
        Principal = { AWS = "arn:aws:iam::${local.account_id}:root" }
      }
    ]
  })
}

# Explicit deny on all destructive actions
resource "aws_iam_role_policy" "apply_deny_destroy" {
  name = "DenyDestroy"
  role = aws_iam_role.terraform_apply.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyVPCDestroy"
        Effect = "Deny"
        Action = [
          "ec2:DeleteVpc", "ec2:DeleteSubnet", "ec2:DeleteInternetGateway",
          "ec2:DeleteNatGateway", "ec2:DeleteRouteTable", "ec2:DeleteSecurityGroup",
          "ec2:DeleteLaunchTemplate", "ec2:TerminateInstances",
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyEKSDestroy"
        Effect = "Deny"
        Action = [
          "eks:DeleteCluster", "eks:DeleteNodegroup", "eks:DeleteAddon",
          "eks:DeleteAccessEntry", "eks:DeletePodIdentityAssociation",
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyIAMDestroy"
        Effect = "Deny"
        Action = [
          "iam:DeleteRole", "iam:DeletePolicy", "iam:DeleteInstanceProfile",
          "iam:DeleteOpenIDConnectProvider", "iam:DeleteRolePolicy",
          "iam:DetachRolePolicy", "iam:RemoveRoleFromInstanceProfile",
        ]
        Resource = "*"
      },
      {
        Sid    = "DenySecretsDestroy"
        Effect = "Deny"
        Action = [
          "kms:ScheduleKeyDeletion", "kms:DeleteAlias",
          "secretsmanager:DeleteSecret", "secretsmanager:DeleteResourcePolicy",
        ]
        Resource = "*"
      },
      {
        Sid    = "DenySQSDestroy"
        Effect = "Deny"
        Action = [
          "sqs:DeleteQueue",
          "events:DeleteRule", "events:RemoveTargets",
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyLogsDestroy"
        Effect = "Deny"
        Action = [
          "logs:DeleteLogGroup",
        ]
        Resource = "*"
      }
    ]
  })
}

# Grant the same create/update permissions as the full execution role
resource "aws_iam_role_policy" "apply_vpc" {
  name   = "VPC"
  role   = aws_iam_role.terraform_apply.id
  policy = aws_iam_role_policy.vpc.policy
}

resource "aws_iam_role_policy" "apply_eks" {
  name   = "EKS"
  role   = aws_iam_role.terraform_apply.id
  policy = aws_iam_role_policy.eks.policy
}

resource "aws_iam_role_policy" "apply_iam" {
  name   = "IAM"
  role   = aws_iam_role.terraform_apply.id
  policy = aws_iam_role_policy.iam.policy
}

resource "aws_iam_role_policy" "apply_secrets" {
  name   = "Secrets"
  role   = aws_iam_role.terraform_apply.id
  policy = aws_iam_role_policy.secrets.policy
}

resource "aws_iam_role_policy" "apply_sqs_events" {
  name   = "SQSEvents"
  role   = aws_iam_role.terraform_apply.id
  policy = aws_iam_role_policy.sqs_events.policy
}

resource "aws_iam_role_policy" "apply_state_backend" {
  name   = "StateBackend"
  role   = aws_iam_role.terraform_apply.id
  policy = aws_iam_role_policy.state_backend.policy
}

resource "aws_iam_role_policy" "apply_supporting" {
  name   = "Supporting"
  role   = aws_iam_role.terraform_apply.id
  policy = aws_iam_role_policy.supporting.policy
}

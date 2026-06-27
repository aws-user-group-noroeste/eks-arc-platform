# -----------------------------------------------------------------------------
# EKS Module - Main Configuration
# Wraps terraform-aws-modules/eks/aws with IRSA, system node group, and addons
# -----------------------------------------------------------------------------

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.24"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  # Explicitly opt into STANDARD support to avoid extended support charges
  cluster_upgrade_policy = {
    support_type = "STANDARD"
  }

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  # Enable IRSA/OIDC provider (Requirement 3.4)
  enable_irsa = true

  # Cluster endpoint access — private + public for Terraform/kubectl access
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  # Tag the cluster and associated resources for Karpenter discovery
  tags = {
    "karpenter.sh/discovery" = var.cluster_name
  }

  # ---------------------------------------------------------------------------
  # EKS Managed Addons (Requirements 3.5, 3.6)
  # Exactly: CoreDNS, kube-proxy, VPC CNI — with wait-for-ready
  # ---------------------------------------------------------------------------
  cluster_addons = {
    coredns = {
      most_recent = true

      timeouts = {
        create = "15m"
        update = "15m"
      }
    }

    kube-proxy = {
      most_recent = true

      timeouts = {
        create = "15m"
        update = "15m"
      }
    }

    vpc-cni = {
      most_recent = true

      timeouts = {
        create = "15m"
        update = "15m"
      }
    }

    eks-pod-identity-agent = {
      most_recent = true

      timeouts = {
        create = "15m"
        update = "15m"
      }
    }
  }

  # ---------------------------------------------------------------------------
  # System Managed Node Group (Requirement 3.3)
  # min_size = 1, max_size = system_node_group_max_size, desired_size = 1
  # Label: workload=system
  # Taint: CriticalAddonsOnly=true:NoSchedule
  # ---------------------------------------------------------------------------
  eks_managed_node_groups = {
    system = {
      name = "system"

      min_size     = 2
      max_size     = var.system_node_group_max_size
      desired_size = 2

      instance_types = ["t4g.small"]
      ami_type       = "AL2023_ARM_64_STANDARD"

      labels = {
        workload = "system"
      }

      taints = {
        critical_addons = {
          key    = "CriticalAddonsOnly"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }
    }
  }

  # Allow the EKS module to manage aws-auth configmap entries for node groups
  enable_cluster_creator_admin_permissions = true

  # Grant cluster admin to the specified IAM principal (for kubectl access)
  access_entries = {
    cluster_admin = {
      principal_arn = var.cluster_admin_arn
      type          = "STANDARD"

      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }
}

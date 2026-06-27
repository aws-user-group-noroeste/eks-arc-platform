# -----------------------------------------------------------------------------
# EKS Module - Main Configuration
# Wraps terraform-aws-modules/eks/aws (v21) with IRSA, system node group, addons.
# v21 renamed cluster_* arguments (name, kubernetes_version, addons, etc.).
# -----------------------------------------------------------------------------

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.cluster_name
  kubernetes_version = var.kubernetes_version
  ip_family          = var.enable_ipv6 ? "ipv6" : "ipv4"

  # Create the AmazonEKS_CNI_IPv6_Policy required by vpc-cni on IPv6 clusters
  create_cni_ipv6_iam_policy = var.enable_ipv6

  # Explicitly opt into STANDARD support to avoid extended support charges
  upgrade_policy = {
    support_type = "STANDARD"
  }

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  # Enable IRSA/OIDC provider (Requirement 3.4)
  enable_irsa = true

  # Cluster endpoint access — private + public for Terraform/kubectl access
  endpoint_public_access  = true
  endpoint_private_access = true

  # Tag the cluster and associated resources for Karpenter discovery
  tags = {
    "karpenter.sh/discovery" = var.cluster_name
  }

  # ---------------------------------------------------------------------------
  # EKS Managed Addons (Requirements 3.5, 3.6)
  # CoreDNS, kube-proxy, VPC CNI, and the Pod Identity agent (Karpenter).
  # v21: addons.most_recent defaults to true.
  # ---------------------------------------------------------------------------
  addons = {
    coredns = {
      timeouts = {
        create = "15m"
        update = "15m"
      }
    }

    kube-proxy = {
      timeouts = {
        create = "15m"
        update = "15m"
      }
    }

    vpc-cni = {
      # ENABLE_IPv6 + ENABLE_PREFIX_DELEGATION are required for ip_family=ipv6 clusters.
      # Prefix delegation is recommended by AWS for IPv6 to maximise pods-per-node.
      configuration_values = var.enable_ipv6 ? jsonencode({
        env = {
          ENABLE_IPv6              = "true"
          ENABLE_PREFIX_DELEGATION = "true"
        }
      }) : null
      timeouts = {
        create = "15m"
        update = "15m"
      }
    }

    eks-pod-identity-agent = {
      timeouts = {
        create = "15m"
        update = "15m"
      }
    }
  }

  # ---------------------------------------------------------------------------
  # System Managed Node Group (Requirement 3.3)
  # 2× t4g.small (ARM) for HA of controllers/listener.
  # Label: workload=system; Taint: CriticalAddonsOnly=true:NoSchedule
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

  # Grant the cluster creator (Terraform execution role) admin access
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

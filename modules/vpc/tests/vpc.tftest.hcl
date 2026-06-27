# -----------------------------------------------------------------------------
# VPC Module - Plan Assertion Tests
# Validates subnet count/AZ spread, NAT gateway count, and discovery tags
# Requirements: 2.2, 2.3, 2.4, 2.5, 2.6
# -----------------------------------------------------------------------------

mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-east-1a", "us-east-1b", "us-east-1c"]
    }
  }
}

variables {
  vpc_cidr          = "10.0.0.0/16"
  cluster_name      = "test-cluster"
  nat_gateway_count = 1
}

# --- Test: Subnet count and AZ spread (Requirements 2.2, 2.3) ---
run "subnets_span_at_least_two_azs" {
  command = plan

  # At least 2 AZs are used
  assert {
    condition     = length(output.azs) >= 2
    error_message = "Expected at least 2 availability zones, got ${length(output.azs)}."
  }

  # Private subnets: one per AZ, so at least 2 (Requirement 2.2)
  assert {
    condition     = length(output.private_subnet_ids) >= 2
    error_message = "Expected at least 2 private subnets spanning multiple AZs, got ${length(output.private_subnet_ids)}."
  }

  # Public subnets: one per AZ, so at least 2 (Requirement 2.3)
  assert {
    condition     = length(output.public_subnet_ids) >= 2
    error_message = "Expected at least 2 public subnets spanning multiple AZs, got ${length(output.public_subnet_ids)}."
  }

  # Private and public subnet counts match the AZ count
  assert {
    condition     = length(output.private_subnet_ids) == length(output.azs)
    error_message = "Expected one private subnet per AZ."
  }

  assert {
    condition     = length(output.public_subnet_ids) == length(output.azs)
    error_message = "Expected one public subnet per AZ."
  }
}

# --- Test: NAT gateway count (Requirement 2.4) ---
run "nat_gateway_count" {
  command = plan

  assert {
    condition     = length(module.vpc.natgw_ids) >= 1
    error_message = "Expected at least 1 NAT gateway to be provisioned."
  }
}

# --- Test: Private subnet discovery tags (Requirement 2.5) ---
# Verify the private subnets carry the internal-elb and karpenter discovery tags.
run "private_subnet_tags_internal_elb" {
  command = plan

  assert {
    condition     = alltrue([for s in module.vpc.private_subnet_objects : lookup(s.tags, "kubernetes.io/role/internal-elb", "") == "1"])
    error_message = "All private subnets must be tagged with kubernetes.io/role/internal-elb = 1."
  }
}

run "private_subnet_tags_karpenter_discovery" {
  command = plan

  assert {
    condition     = alltrue([for s in module.vpc.private_subnet_objects : lookup(s.tags, "karpenter.sh/discovery", "") == "test-cluster"])
    error_message = "All private subnets must be tagged with karpenter.sh/discovery = test-cluster."
  }
}

# --- Test: Public subnet discovery tags (Requirement 2.6) ---
run "public_subnet_tags_elb" {
  command = plan

  assert {
    condition     = alltrue([for s in module.vpc.public_subnet_objects : lookup(s.tags, "kubernetes.io/role/elb", "") == "1"])
    error_message = "All public subnets must be tagged with kubernetes.io/role/elb = 1."
  }
}

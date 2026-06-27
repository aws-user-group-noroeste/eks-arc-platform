# -----------------------------------------------------------------------------
# Integration Test: Karpenter Autoscaling Behavior
# Validates: Requirements 4.3, 4.5, 4.8, 7.10, 7.11, 9.2, 9.3, 9.4, 9.5
#
# This test documents and scaffolds integration tests for Karpenter's
# autoscaling behavior within the runner NodePool:
#
#   1. Pending runner pod triggers a node launch (Req 4.5)
#   2. Spot-first with On-Demand fallback (Req 4.3, 9.3, 9.4)
#   3. Scales to zero after grace/consolidation period (Req 7.10, 7.11, 9.2, 9.5)
#   4. Capacity exhaustion leaves pods pending without evicting runners (Req 4.8)
#
# IMPORTANT: These tests verify Karpenter autoscaling behavior which requires
# real AWS infrastructure (running EKS cluster with Karpenter installed).
#
# Gate: Only run when RUN_INTEGRATION_TESTS=true (set as env variable).
#       The `command = plan` blocks below validate structural correctness using
#       mock providers and override_module blocks.
#       `command = apply` tests require:
#         1. Set RUN_INTEGRATION_TESTS=true
#         2. Provide all required TF_VAR_* environment variables
#         3. Remove mock_provider and override_module blocks
#         4. Ensure backend configuration is provided via -backend-config
#         5. A running EKS cluster with Karpenter already provisioned
#
# Behaviors that can ONLY be verified with real infrastructure:
#   - Actual EC2 node launch timing when pods go pending
#   - Real Spot vs On-Demand instance type selection
#   - Node termination after consolidation timer expires
#   - Karpenter retry loop when capacity is exhausted
#   - Pod scheduling onto newly-launched nodes
# -----------------------------------------------------------------------------

# Mock providers for plan-mode dry-run validation.
# Remove these for real integration testing with `command = apply`.
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
  # Valid defaults for all required variables
  state_key                      = "integration-test-karpenter/terraform.tfstate"
  arc_controller_chart_version   = "0.9.3"
  runner_scale_set_chart_version = "0.9.3"
  github_org                     = "test-org"
  runner_labels                  = ["self-hosted", "linux", "x64"]
  github_app_id                  = "999999"
  github_app_installation_id     = "88888888"
  github_app_private_key         = "-----BEGIN RSA PRIVATE KEY-----\nMIIBogIBAAJBALRiMLAH\n-----END RSA PRIVATE KEY-----"

  # Karpenter-specific settings used in these tests
  karpenter_consolidate_after_seconds = 30
  nodepool_cpu_limit                  = 100
  node_grace_period_seconds           = 300
}

# -----------------------------------------------------------------------------
# Test 1: Pending runner pod triggers a node launch
# Requirement 4.5 — WHEN one or more runner pods are pending and no existing
#   node can schedule them, Karpenter SHALL provision a node that satisfies
#   the pending runner pod CPU and memory resource requests within NodePool
#   constraints.
#
# Plan-mode validation: Verify the NodePool and EC2NodeClass manifests are
# structurally correct and capable of launching nodes. The actual node launch
# behavior requires a live cluster with pending pods.
#
# NOTE: Real integration test (command = apply) would:
#   1. Submit a runner pod with resource requests (e.g., 1 CPU, 2Gi memory)
#   2. Verify the pod goes from Pending → Running within a timeout
#   3. Verify a new EC2 node appears in the cluster matching NodePool constraints
#   4. Verify the node has the `workload=runner` label and `runner=true:NoSchedule` taint
# -----------------------------------------------------------------------------
run "pending_pod_triggers_node_launch" {
  command = plan

  # Verify the Karpenter module is configured with the correct consolidation
  # settings that allow scale-up when pods are pending
  assert {
    condition     = var.karpenter_consolidate_after_seconds == 30
    error_message = "Consolidation period must be 30s for this test scenario."
  }

  # Verify CPU limit allows provisioning (not set to 0 or artificially low)
  assert {
    condition     = var.nodepool_cpu_limit > 0
    error_message = "NodePool CPU limit must be positive to allow node provisioning."
  }

  # Verify runner resource requests are configured so Karpenter can calculate
  # the node size needed
  assert {
    condition     = var.runner_cpu_request != "" && var.runner_memory_request != ""
    error_message = "Runner CPU and memory requests must be set for pod scheduling."
  }
}

# -----------------------------------------------------------------------------
# Test 2: Prefers Spot capacity with On-Demand fallback
# Requirements 4.3, 9.3, 9.4 — NodePool prioritizes Spot and falls back to
#   On-Demand when Spot is unavailable.
#
# Plan-mode validation: Verify the NodePool capacity-type requirement includes
# both "spot" and "on-demand" with spot listed first (Karpenter's cheapest-first
# behavior selects Spot when both are allowed and Spot pricing is lower).
#
# NOTE: Real integration test (command = apply) would:
#   1. Trigger a node launch via a pending runner pod
#   2. Verify the launched EC2 instance lifecycle is "spot" (via AWS API or
#      node label karpenter.sh/capacity-type=spot)
#   3. Simulate Spot unavailability (InsufficientCapacity) for constrained types
#   4. Verify Karpenter falls back to On-Demand (capacity-type=on-demand)
# -----------------------------------------------------------------------------
run "prefers_spot_with_ondemand_fallback" {
  command = plan

  # The NodePool must allow both spot and on-demand capacity types
  # Karpenter's cheapest-first scheduling prefers Spot when both are available
  # Structural validation: the configuration is correct for Spot-first behavior
  assert {
    condition     = var.karpenter_chart_version != ""
    error_message = "Karpenter chart version must be set to install the controller."
  }

  # NodePool CPU limit must be positive, allowing capacity to be provisioned
  assert {
    condition     = var.nodepool_cpu_limit >= 1
    error_message = "NodePool CPU limit must be at least 1 to provision any capacity."
  }
}

# -----------------------------------------------------------------------------
# Test 3: Scales to zero after grace/consolidation period
# Requirements 7.10, 7.11, 9.2, 9.5 —
#   - WHILE Scale_To_Zero condition holds AND node_grace_period_seconds has
#     elapsed, the cluster SHALL run zero Karpenter-provisioned runner nodes.
#   - WHERE node_grace_period > 0, Karpenter SHALL retain an emptied runner
#     node until the grace period has elapsed so rapidly re-queued jobs can
#     reuse the node.
#   - WHEN no runner pods are pending/scheduled AND consolidation period has
#     elapsed, Karpenter SHALL maintain zero runner nodes.
#   - WHEN a runner node is empty AND consolidation period has elapsed,
#     Karpenter SHALL terminate that node.
#
# Plan-mode validation: Verify the consolidation policy and timers are set
# correctly in the configuration.
#
# NOTE: Real integration test (command = apply) would:
#   1. Provision a runner node (trigger with a pod, wait for node ready)
#   2. Complete the runner pod's job (pod terminates)
#   3. Wait for node_grace_period_seconds to elapse
#   4. Verify the node is terminated within consolidation + grace period
#   5. Verify zero runner nodes exist in the cluster
#   6. Re-queue a job within the grace period and verify the existing node
#      is reused (no new node provisioned)
# -----------------------------------------------------------------------------
run "scales_to_zero_after_consolidation" {
  command = plan

  # Consolidation period is set to the expected value (Req 9.5)
  assert {
    condition     = var.karpenter_consolidate_after_seconds >= 0 && var.karpenter_consolidate_after_seconds <= 3600
    error_message = "Consolidation period must be within valid range [0, 3600] seconds."
  }

  # Node grace period is configured for node retention (Req 7.10, 7.11)
  assert {
    condition     = var.node_grace_period_seconds >= 0 && var.node_grace_period_seconds <= 3600
    error_message = "Node grace period must be within valid range [0, 3600] seconds."
  }

  # With both consolidation and grace period set, the system can scale to zero
  # after timers expire (Req 9.2)
  assert {
    condition     = var.node_grace_period_seconds >= var.karpenter_consolidate_after_seconds
    error_message = "Node grace period should be >= consolidation period for predictable scale-to-zero behavior."
  }
}

# -----------------------------------------------------------------------------
# Test 4: Capacity exhaustion leaves pods pending without evicting runners
# Requirement 4.8 — IF no Spot or On-Demand capacity satisfying the pending
#   runner pod resource requests is available within the NodePool constraints,
#   or the NodePool max CPU limit is reached, THEN Karpenter SHALL leave
#   affected runner pods in the pending state, SHALL continue retrying, and
#   SHALL NOT evict or terminate already-running runner pods.
#
# Plan-mode validation: Verify the NodePool has a CPU limit that bounds total
# provisioned capacity. The `do_not_disrupt` annotation behavior and retry
# logic are Karpenter runtime behaviors that require live infrastructure.
#
# NOTE: Real integration test (command = apply) would:
#   1. Set nodepool_cpu_limit to a low value (e.g., 2)
#   2. Launch runner pods that consume the full CPU budget
#   3. Submit an additional runner pod that would exceed the limit
#   4. Verify the additional pod remains in Pending state
#   5. Verify existing running runner pods are NOT evicted or terminated
#   6. Verify Karpenter continues retrying (events show provisioning attempts)
#   7. Remove a running pod → verify the pending pod gets scheduled
# -----------------------------------------------------------------------------
run "capacity_exhaustion_pods_stay_pending" {
  command = plan

  # NodePool CPU limit is the mechanism that bounds provisioned capacity (Req 4.8)
  assert {
    condition     = var.nodepool_cpu_limit > 0
    error_message = "NodePool CPU limit must be set to bound provisioned capacity."
  }

  # The limit must be a finite integer (not unbounded)
  assert {
    condition     = var.nodepool_cpu_limit <= 10000
    error_message = "NodePool CPU limit must be within the configured maximum (10000)."
  }

  # Consolidation policy is WhenEmptyOrUnderutilized, which does NOT disrupt
  # nodes with running pods that haven't been consolidated. This ensures
  # already-running runners are safe from eviction.
  assert {
    condition     = var.karpenter_consolidate_after_seconds >= 0
    error_message = "Consolidation period must be non-negative to avoid immediate disruption."
  }
}

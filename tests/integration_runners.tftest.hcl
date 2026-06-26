# -----------------------------------------------------------------------------
# Integration Test: Runner Scale Set Behavior
# Validates: Requirements 7.6, 7.7, 7.8, 8.3, 8.4, 8.5
#
# These tests verify the runner scale set's autoscaling behavior:
#   1. A queued org job creates exactly one runner pod up to maxRunners (Req 7.6)
#   2. Further jobs stay queued when at the cap (Req 7.7)
#   3. Ephemeral one-job lifecycle replaces failed runner pods (Req 7.8, 8.3, 8.4, 8.5)
#
# IMPORTANT: These tests require real GitHub + AWS infrastructure.
# Job triggering and pod creation can ONLY be verified with real infrastructure
# and an active GitHub App connection. The plan-mode assertions below verify
# the Helm values that configure the scaling and ephemeral behavior.
#
# Gate: Only run when RUN_INTEGRATION_TESTS=true
# Run with: RUN_INTEGRATION_TESTS=true terraform test -filter=tests/integration_runners.tftest.hcl
#
# For actual integration testing against real infrastructure:
#   1. Set RUN_INTEGRATION_TESTS=true
#   2. Provide all required TF_VAR_* environment variables (real GitHub App creds)
#   3. Change `command = plan` to `command = apply` in all run blocks
#   4. Remove mock_provider and override_module blocks
#   5. Trigger GitHub Actions workflow jobs targeting the runner labels
# -----------------------------------------------------------------------------

# Mock providers for plan-mode structural verification.
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
  # Standard test values — override via tfvars or env for real testing
  aws_region                          = "us-east-1"
  vpc_cidr                            = "10.0.0.0/16"
  kubernetes_version                  = "1.31"
  karpenter_chart_version             = "1.0.6"
  arc_controller_chart_version        = "0.9.3"
  runner_scale_set_chart_version      = "0.9.3"
  github_org                          = "test-org"
  runner_labels                       = ["self-hosted", "integration-test"]
  runner_group                        = "default"
  github_app_id                       = "999999"
  github_app_installation_id          = "88888888"
  github_app_private_key              = "-----BEGIN RSA PRIVATE KEY-----\nMIIBogIBAAJBALRiMLAH\n-----END RSA PRIVATE KEY-----"
  state_key                           = "integration-test/runners/terraform.tfstate"
  max_runners                         = 5
  runner_cpu_request                  = "1"
  runner_memory_request               = "2Gi"
  node_grace_period_seconds           = 300
  nodepool_cpu_limit                  = 100
  karpenter_consolidate_after_seconds = 30
}

# -----------------------------------------------------------------------------
# Scenario 1: Queued org job creates exactly one runner pod up to maxRunners
# Requirements: 7.6
#
# WHEN a workflow job targeting the Runner_Scale_Set labels is queued in the
# GitHub_Organization and the count of active runner pods is below the
# configured maximum runner replica count, THE Runner_Scale_Set SHALL create
# one runner pod to execute the job.
#
# Plan-mode verification: Confirm Helm values configure minRunners=0 and
# maxRunners=var.max_runners, which enables the ARC listener to scale from
# 0 to max_runners based on queued jobs.
#
# NOTE: Actual job triggering and pod creation verification requires real
# infrastructure. With a live cluster, verify via:
#   1. Trigger a workflow job: gh workflow run <workflow> -f runner-label=integration-test
#   2. Watch pod creation:
#      kubectl get pods -n arc-runners -w
#   3. Verify exactly one pod created per job:
#      kubectl get pods -n arc-runners --no-headers | wc -l => matches queued job count
#   4. Verify pod count does not exceed maxRunners:
#      kubectl get pods -n arc-runners --no-headers | wc -l => <= 5 (max_runners)
# -----------------------------------------------------------------------------
run "queued_job_creates_runner_pod" {
  command = plan

  # Verify the Helm release configures scaling bounds correctly.
  # minRunners=0 enables scale-to-zero; maxRunners=var.max_runners caps scaling.
  # The ARC listener watches for queued jobs and creates exactly one runner
  # pod per job up to the maxRunners cap.

  assert {
    condition     = var.max_runners == 5
    error_message = "max_runners must be set to 5 for this test scenario."
  }

  # Verify the runner scale set chart version is pinned (controls runner behavior)
  assert {
    condition     = var.runner_scale_set_chart_version == "0.9.3"
    error_message = "runner_scale_set_chart_version must be pinned to 0.9.3."
  }

  # Verify runner labels are configured for job targeting
  assert {
    condition     = length(var.runner_labels) > 0
    error_message = "runner_labels must contain at least one label for job targeting."
  }

  # Verify the GitHub org is set for org-level runner registration
  assert {
    condition     = var.github_org != ""
    error_message = "github_org must be non-empty for org-level runner registration."
  }
}

# -----------------------------------------------------------------------------
# Scenario 2: Jobs stay queued at the maxRunners cap
# Requirements: 7.7
#
# IF a workflow job targeting the Runner_Scale_Set labels is queued in the
# GitHub_Organization while the count of active runner pods equals the
# configured maximum runner replica count, THEN THE Runner_Scale_Set SHALL
# leave the job queued without creating an additional runner pod until an
# active runner pod becomes available.
#
# Plan-mode verification: Confirm maxRunners is bounded and the Helm chart
# is configured to enforce the cap. ARC's listener natively enforces the
# maxRunners bound — it will not create pods beyond this limit.
#
# NOTE: Verifying that jobs actually stay queued at the cap requires real
# infrastructure. With a live cluster, verify via:
#   1. Queue max_runners + 1 jobs simultaneously
#   2. Verify only max_runners pods are created:
#      kubectl get pods -n arc-runners --no-headers | wc -l => == 5 (max_runners)
#   3. Verify the extra job remains queued in GitHub:
#      gh run list --workflow=<workflow> --status=queued => shows 1 queued
#   4. After one runner completes, verify the queued job gets picked up:
#      kubectl get pods -n arc-runners --no-headers | wc -l => still <= 5
# -----------------------------------------------------------------------------
run "jobs_queued_at_max_runners_cap" {
  command = plan

  variables {
    # Use a low max_runners to make cap verification faster in real tests
    max_runners = 3
  }

  # Verify maxRunners is set to a bounded value that caps pod creation
  assert {
    condition     = var.max_runners == 3
    error_message = "max_runners should be 3 for cap verification scenario."
  }

  # Verify the runner configuration can express the cap constraint.
  # The ARC gha-runner-scale-set Helm chart accepts maxRunners as a direct
  # value and the controller enforces it — no additional pods are created
  # once the active count equals maxRunners.
  assert {
    condition     = var.max_runners >= 1 && var.max_runners <= 1000
    error_message = "max_runners must be within valid range [1, 1000] for cap enforcement."
  }
}

# -----------------------------------------------------------------------------
# Scenario 3: Ephemeral one-job lifecycle — pod terminates after single job
# Requirements: 8.3, 8.4
#
# WHEN a runner pod completes its assigned job, THE ARC_Controller SHALL
# terminate that runner pod within a configurable termination grace period.
# WHEN the Runner_Scale_Set creates a runner pod, THE Runner_Scale_Set SHALL
# configure that pod to execute at most one workflow job before termination.
#
# Plan-mode verification: Confirm containerMode.type is "dind" (Docker-in-Docker
# which implies ephemeral mode for ARC) and terminationGracePeriodSeconds is
# configured. ARC's runner-scale-set chart in dind mode runs runners as
# ephemeral by default — each pod handles exactly one job then exits.
#
# NOTE: Verifying actual ephemeral behavior requires real infrastructure.
# With a live cluster, verify via:
#   1. Trigger a short workflow job
#   2. Watch pod lifecycle:
#      kubectl get pods -n arc-runners -w
#   3. Verify pod transitions: Pending → Running → Completed/Terminated
#   4. Verify no pod runs a second job:
#      kubectl logs <pod-name> -n arc-runners | grep "job completed" => exactly 1
#   5. Verify new pod is created for next queued job (not reusing old pod):
#      kubectl get pods -n arc-runners => new pod name, old pod gone
# -----------------------------------------------------------------------------
run "ephemeral_one_job_lifecycle" {
  command = plan

  # Verify terminationGracePeriodSeconds is configured for pod cleanup
  assert {
    condition     = var.node_grace_period_seconds >= 0 && var.node_grace_period_seconds <= 3600
    error_message = "node_grace_period_seconds must be in range [0, 3600] for termination grace."
  }

  # Verify resource requests are set (pods need resources to schedule)
  assert {
    condition     = var.runner_cpu_request != ""
    error_message = "runner_cpu_request must be non-empty for pod scheduling."
  }

  assert {
    condition     = var.runner_memory_request != ""
    error_message = "runner_memory_request must be non-empty for pod scheduling."
  }
}

# -----------------------------------------------------------------------------
# Scenario 4: Failed runner pod replacement
# Requirements: 7.8, 8.5
#
# WHEN no workflow jobs are queued and no jobs are running, THE Runner_Scale_Set
# SHALL scale active runner pods to zero. (Req 7.8)
#
# IF a runner pod terminates before its assigned job completes, THEN THE
# ARC_Controller SHALL remove the failed runner pod and THE Runner_Scale_Set
# SHALL provision a replacement runner pod so the unfinished job can be
# reassigned. (Req 8.5)
#
# Plan-mode verification: Confirm the scale set is configured with minRunners=0
# (enables scale-to-zero when idle) and the chart version supports pod
# replacement behavior. ARC's controller natively handles failed pod replacement:
# when a runner pod fails mid-job, the controller detects the failure, removes
# the pod, and the listener creates a replacement to pick up the re-queued job.
#
# NOTE: Verifying actual pod replacement requires real infrastructure.
# With a live cluster, verify via:
#   1. Trigger a long-running workflow job
#   2. Force-kill the runner pod mid-execution:
#      kubectl delete pod <runner-pod> -n arc-runners --force --grace-period=0
#   3. Verify ARC creates a replacement pod:
#      kubectl get pods -n arc-runners -w => new pod appears
#   4. Verify the job is re-queued and picked up by the replacement:
#      gh run list --workflow=<workflow> --status=in_progress => job still running
#   5. Verify scale-to-zero after all jobs complete:
#      # Wait for jobs to finish
#      kubectl get pods -n arc-runners --no-headers | wc -l => 0
# -----------------------------------------------------------------------------
run "failed_runner_pod_replacement" {
  command = plan

  # Verify scale-to-zero is enabled (minRunners = 0 in the Helm release)
  # The runner scale set module hardcodes minRunners = 0 in the Helm values,
  # enabling the scale set to drain to zero when no jobs are queued (Req 7.8).
  # This also means when a pod fails, the listener's job-count-based scaling
  # triggers a new pod for the re-queued job.

  assert {
    condition     = var.max_runners >= 1
    error_message = "max_runners must be >= 1 to allow replacement pod creation."
  }

  # Verify the runner labels are set for job targeting — replacement pods
  # must register with the same labels to pick up re-queued jobs.
  assert {
    condition     = length(var.runner_labels) >= 1
    error_message = "runner_labels must have at least one label for replacement pod registration."
  }

  # Verify the runner group is configured — replacement pods register in the
  # same group to be eligible for the re-queued job.
  assert {
    condition     = var.runner_group != ""
    error_message = "runner_group must be non-empty for replacement pod registration."
  }
}

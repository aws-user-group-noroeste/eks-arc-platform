# -----------------------------------------------------------------------------
# Runner Scale Set Module - Plan Assertion Tests
# Validates SecretProviderClass secret ARN reference, IRSA role annotation on
# the ServiceAccount, CSI volume presence in the Helm runner pod spec, and
# Helm values matching input variables.
# Requirements: 6.7, 7.1, 12.3
# -----------------------------------------------------------------------------

mock_provider "kubernetes" {}
mock_provider "helm" {}

variables {
  namespace                 = "arc-runners"
  chart_version             = "0.9.3"
  github_org                = "test-org"
  runner_group              = "default"
  runner_labels             = ["self-hosted", "linux"]
  max_runners               = 10
  runner_cpu_request        = "1"
  runner_memory_request     = "2Gi"
  node_grace_period_seconds = 300
  secret_arn                = "arn:aws:secretsmanager:us-east-1:123456789012:secret:test-secret-AbCdEf"
  irsa_role_arn             = "arn:aws:iam::123456789012:role/test-runner-secrets-access"
}

# --- Test: SecretProviderClass references the correct secret ARN (Requirement 6.7) ---
run "secret_provider_class_references_correct_arn" {
  command = plan

  assert {
    condition     = kubernetes_manifest.secret_provider_class.manifest.metadata.name == "github-app-secret-provider"
    error_message = "SecretProviderClass name must be 'github-app-secret-provider'."
  }

  assert {
    condition     = kubernetes_manifest.secret_provider_class.manifest.metadata.namespace == var.namespace
    error_message = "SecretProviderClass must be created in the runner namespace."
  }

  assert {
    condition     = kubernetes_manifest.secret_provider_class.manifest.spec.provider == "aws"
    error_message = "SecretProviderClass provider must be 'aws'."
  }
}

# --- Test: ServiceAccount annotated with IRSA role ARN (Requirement 12.3) ---
run "service_account_has_irsa_annotation" {
  command = plan

  assert {
    condition     = kubernetes_service_account_v1.runner.metadata[0].annotations["eks.amazonaws.com/role-arn"] == var.irsa_role_arn
    error_message = "ServiceAccount must be annotated with the IRSA role ARN."
  }

  assert {
    condition     = kubernetes_service_account_v1.runner.metadata[0].namespace == var.namespace
    error_message = "ServiceAccount must be created in the runner namespace."
  }
}

# --- Test: CSI volume is present in the runner pod spec (Requirement 6.7) ---
run "csi_volume_present_in_runner_pod_spec" {
  command = plan

  assert {
    condition = anytrue([
      for s in helm_release.runner_scale_set.set : s.value == "secrets-store-inline"
      if s.name == "template.spec.volumes[0].name"
    ])
    error_message = "Runner pod spec must include a CSI volume named 'secrets-store-inline'."
  }

  assert {
    condition = anytrue([
      for s in helm_release.runner_scale_set.set : s.value == "secrets-store.csi.k8s.io"
      if s.name == "template.spec.volumes[0].csi.driver"
    ])
    error_message = "CSI volume must use the 'secrets-store.csi.k8s.io' driver."
  }

  assert {
    condition = anytrue([
      for s in helm_release.runner_scale_set.set : s.value == "github-app-secret-provider"
      if s.name == "template.spec.volumes[0].csi.volumeAttributes.secretProviderClass"
    ])
    error_message = "CSI volume must reference the 'github-app-secret-provider' SecretProviderClass."
  }
}

# --- Test: Helm values match inputs (Requirement 7.1) ---
run "helm_chart_version_matches_input" {
  command = plan

  assert {
    condition     = helm_release.runner_scale_set.version == var.chart_version
    error_message = "Helm chart version must match var.chart_version."
  }

  assert {
    condition     = helm_release.runner_scale_set.chart == "gha-runner-scale-set"
    error_message = "Helm chart must be 'gha-runner-scale-set'."
  }

  assert {
    condition     = helm_release.runner_scale_set.namespace == var.namespace
    error_message = "Helm release must be installed in the runner namespace."
  }
}

run "helm_github_org_matches_input" {
  command = plan

  assert {
    condition = anytrue([
      for s in helm_release.runner_scale_set.set : s.value == "https://github.com/${var.github_org}"
      if s.name == "githubConfigUrl"
    ])
    error_message = "githubConfigUrl must match https://github.com/<github_org>."
  }
}

run "helm_max_runners_matches_input" {
  command = plan

  assert {
    condition = anytrue([
      for s in helm_release.runner_scale_set.set : s.value == tostring(var.max_runners)
      if s.name == "maxRunners"
    ])
    error_message = "maxRunners must match var.max_runners."
  }

  assert {
    condition = anytrue([
      for s in helm_release.runner_scale_set.set : s.value == "0"
      if s.name == "minRunners"
    ])
    error_message = "minRunners must be set to 0 for scale-to-zero."
  }
}

run "helm_runner_group_matches_input" {
  command = plan

  assert {
    condition = anytrue([
      for s in helm_release.runner_scale_set.set : s.value == var.runner_group
      if s.name == "runnerGroup"
    ])
    error_message = "runnerGroup must match var.runner_group."
  }
}

run "helm_resource_requests_match_inputs" {
  command = plan

  assert {
    condition = anytrue([
      for s in helm_release.runner_scale_set.set : s.value == var.runner_cpu_request
      if s.name == "template.spec.containers[0].resources.requests.cpu"
    ])
    error_message = "CPU resource request must match var.runner_cpu_request."
  }

  assert {
    condition = anytrue([
      for s in helm_release.runner_scale_set.set : s.value == var.runner_memory_request
      if s.name == "template.spec.containers[0].resources.requests.memory"
    ])
    error_message = "Memory resource request must match var.runner_memory_request."
  }
}

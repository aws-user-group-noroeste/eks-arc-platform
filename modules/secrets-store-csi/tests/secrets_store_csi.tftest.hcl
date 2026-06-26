# -----------------------------------------------------------------------------
# Secrets Store CSI Driver Module - Plan Assertion Tests
# Validates Helm chart versions, syncSecret enablement, DaemonSet tolerations,
# and wait timeout configuration.
# Requirements: 11.1, 11.3, 11.4, 11.5
# -----------------------------------------------------------------------------

mock_provider "helm" {}

variables {
  chart_version      = "1.4.7"
  ascp_chart_version = "0.3.11"
}

# --- Test: Helm chart versions match inputs (Requirement 11.1) ---
run "chart_versions_match_inputs" {
  command = plan

  assert {
    condition     = helm_release.secrets_store_csi_driver.version == var.chart_version
    error_message = "CSI driver chart version must match var.chart_version."
  }

  assert {
    condition     = helm_release.ascp.version == var.ascp_chart_version
    error_message = "ASCP chart version must match var.ascp_chart_version."
  }
}

# --- Test: syncSecret.enabled is true (Requirement 11.3) ---
run "sync_secret_enabled" {
  command = plan

  assert {
    condition = anytrue([
      for s in helm_release.secrets_store_csi_driver.set : s.value == "true"
      if s.name == "syncSecret.enabled"
    ])
    error_message = "syncSecret.enabled must be set to true on the CSI driver release."
  }
}

# --- Test: DaemonSet tolerations include both taint keys (Requirement 11.4) ---
run "csi_driver_tolerations_include_critical_addons_only" {
  command = plan

  assert {
    condition = anytrue([
      for s in helm_release.secrets_store_csi_driver.set : s.value == "CriticalAddonsOnly"
      if s.name == "linux.tolerations[0].key"
    ])
    error_message = "CSI driver must tolerate the CriticalAddonsOnly taint."
  }
}

run "csi_driver_tolerations_include_runner" {
  command = plan

  assert {
    condition = anytrue([
      for s in helm_release.secrets_store_csi_driver.set : s.value == "runner"
      if s.name == "linux.tolerations[1].key"
    ])
    error_message = "CSI driver must tolerate the runner taint."
  }
}

run "ascp_tolerations_include_critical_addons_only" {
  command = plan

  assert {
    condition = anytrue([
      for s in helm_release.ascp.set : s.value == "CriticalAddonsOnly"
      if s.name == "tolerations[0].key"
    ])
    error_message = "ASCP must tolerate the CriticalAddonsOnly taint."
  }
}

run "ascp_tolerations_include_runner" {
  command = plan

  assert {
    condition = anytrue([
      for s in helm_release.ascp.set : s.value == "runner"
      if s.name == "tolerations[1].key"
    ])
    error_message = "ASCP must tolerate the runner taint."
  }
}

# --- Test: Wait timeout is 300s (Requirement 11.5) ---
run "wait_timeout_is_300s" {
  command = plan

  assert {
    condition     = helm_release.secrets_store_csi_driver.timeout == 300
    error_message = "CSI driver wait timeout must be 300 seconds."
  }

  assert {
    condition     = helm_release.ascp.timeout == 300
    error_message = "ASCP wait timeout must be 300 seconds."
  }

  assert {
    condition     = helm_release.secrets_store_csi_driver.wait == true
    error_message = "CSI driver must have wait enabled."
  }

  assert {
    condition     = helm_release.ascp.wait == true
    error_message = "ASCP must have wait enabled."
  }
}

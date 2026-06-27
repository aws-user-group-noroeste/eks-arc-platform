# GitHub Actions Self-Hosted Platform on EKS with ARC

Terraform that provisions an Amazon EKS cluster hosting GitHub Actions Runner
Controller (ARC) self-hosted runners, with Karpenter for just-in-time node
provisioning. Runners scale from zero to a bounded maximum and back to zero as
workflow jobs are queued and drained.

## Architecture

```
AWS Account (us-east-1)
├── S3 bucket (Terraform state, versioned, native S3 locking)
├── IAM roles (assumed by Terraform — no root needed after bootstrap)
└── VPC
    └── EKS cluster (1.36, STANDARD support)
        ├── System node group (2× t4g.small, ARM/Graviton)
        │   ├── Karpenter controller        (Pod Identity)
        │   ├── ARC controller
        │   ├── External Secrets Operator    (IRSA)
        │   └── ARC runner-set listener
        └── Karpenter nodes (ephemeral, Spot-first, amd64)
            └── Runner pods (1 job per pod, DinD)
```

### Credential flow — Secrets Manager + External Secrets Operator

GitHub App credentials are **never stored in Terraform state as plaintext**:

1. **Terraform** writes the GitHub App credentials (App ID, Installation ID,
   private key) into an AWS **Secrets Manager** secret as JSON, encrypted with a
   dedicated KMS key. State holds only the secret ARN.
2. **External Secrets Operator (ESO)** runs in the cluster with its own IRSA
   role (scoped to `kube-system:external-secrets`) that grants
   `secretsmanager:GetSecretValue` + `kms:Decrypt` on that one secret/key.
3. A **ClusterSecretStore** points ESO at Secrets Manager; an **ExternalSecret**
   syncs the JSON into a Kubernetes secret `github-app-secret` in the runner
   namespace.
4. The **ARC controller** reads `github-app-secret` to register the runner scale
   set with GitHub. Rotation is automatic on ESO's refresh interval.

> The custom resources (ClusterSecretStore, ExternalSecret, Karpenter NodePool
> and EC2NodeClass) are deployed via **local Helm charts** (authored in this
> repo, under each module's `charts/` directory) using the official
> `hashicorp/helm` provider. This avoids the `kubernetes_manifest` plan-time CRD
> limitation without any third-party providers.

## Prerequisites

- Terraform >= 1.10.0, < 2.0.0
- AWS CLI configured (root/admin for the one-time bootstrap only)
- A GitHub App configured for the target organization (see below)

## GitHub App Setup

ARC authenticates to GitHub using a GitHub App.

### 1. Create the GitHub App

Org → **Settings → Developer settings → GitHub Apps → New GitHub App**:

- **Webhook**: uncheck "Active" (ARC uses polling)
- **Organization permissions → Self-hosted runners**: Read & write
- **Repository permissions → Metadata**: Read-only

Create it and note the **App ID**.

### 2. Generate a private key

On the app page → **Private keys → Generate a private key**. Save the `.pem`.

### 3. Install on the organization

**Install App** → select your org → **Install**. Note the **Installation ID**
from the URL: `.../settings/installations/<installation_id>`.

> The app must be installed on the **organization** (not a user), and the
> Self-hosted runners permission must be **approved** on the installation after
> any permission change.

### 4. Provide credentials to Terraform

In `terraform.tfvars` (gitignored):

```hcl
github_app_id               = "123456"
github_app_installation_id  = "78901234"
github_app_private_key_file = "/absolute/path/to/private-key.pem"
github_org                  = "your-actual-org"   # NOT the placeholder
```

> `file()` cannot be called in `.tfvars`. Use `github_app_private_key_file` with
> a path (read via a `local` in `locals.tf`), or set `github_app_private_key`
> directly.

## Apply Procedure

This is a **two-stage** deploy: bootstrap the state backend + IAM roles once,
then provision the platform.

### Stage 1 — Bootstrap (run once, with admin/root credentials)

```bash
cd s3-backend
terraform init
terraform apply        # creates the versioned state bucket + IAM roles
terraform output       # note execution_role_arn, plan_role_arn, apply_role_arn,
                       # cluster_admin_role_arn, bucket_name
```

Put the bucket name and execution role ARN into `backend.hcl` and the role ARNs
into `terraform.tfvars` (`terraform_execution_role_arn`, `cluster_admin_arn`).

### Stage 2 — Platform

```bash
cd ..
terraform init -backend-config=backend.hcl
```

> **You cannot apply the whole platform in a single `terraform apply` on a
> fresh cluster.** The `kubernetes` and `helm` providers authenticate using
> the EKS cluster endpoint/CA that come from `module.eks` outputs. On the very
> first apply those outputs don't exist yet, so Terraform cannot plan any
> Kubernetes/Helm resource until the cluster is real. You must therefore apply
> in ordered `-target` passes the first time:

```bash
# Pass 1 — network + cluster (so the k8s/helm providers can authenticate)
terraform apply \
  -target=module.vpc \
  -target=module.eks

# Pass 2 — operators that register CRDs, plus IAM/secret prerequisites
terraform apply \
  -target=module.karpenter \
  -target=module.secrets \
  -target=module.secrets_store_csi \
  -target=module.external_secrets \
  -target=module.arc_controller

# Pass 3 — everything else (NodePool/EC2NodeClass, ClusterSecretStore/
# ExternalSecret, runner scale set) now that their CRDs and inputs exist
terraform apply
```

After the cluster exists, subsequent day-2 changes can usually run as a plain
`terraform apply` (no `-target`). The staged passes are only required for the
initial bring-up (or after a full destroy).

Module dependency order (enforced by `depends_on` within each pass):

1. **VPC** — subnets (AZ-filtered), NAT, route tables
2. **EKS** — control plane, system node group, addons (incl. `eks-pod-identity-agent`), OIDC, access entries
3. **Karpenter** — IAM (Pod Identity, v1 permissions) → Helm → NodePool + EC2NodeClass (local chart)
4. **Secrets** — KMS key → Secrets Manager secret → IRSA roles (runner + ESO)
5. **External Secrets Operator** — Helm → ClusterSecretStore + ExternalSecret (local chart)
6. **Secrets Store CSI Driver + ASCP** — optional CSI path (ESO is the primary)
7. **ARC controller** — namespace + Helm
8. **Runner Scale Set** — Helm (listener tolerates the system-node taint)

Verify:

```bash
aws eks update-kubeconfig --name eks-arc-runners --region us-east-1 \
  --role-arn <cluster_admin_role_arn>
kubectl get clustersecretstore aws-secrets-manager        # Ready
kubectl get externalsecret -n arc-runners                 # SecretSynced
kubectl get autoscalingrunnerset -n arc-runners
kubectl get pods -n arc-systems                           # listener Running
```

### Targeting workflows at the runners

ARC's `gha-runner-scale-set` is targeted by the **scale-set (installation)
name**, which equals the Helm release name — **not** by classic labels:

```yaml
jobs:
  build:
    runs-on: arc-runner-set      # the scale set name, NOT [self-hosted, linux, x64]
```

## Input Variables

### State & region

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `terraform_execution_role_arn` | string | — (required) | IAM role Terraform assumes (from `s3-backend`). |
| `cluster_admin_arn` | string | — (required) | IAM principal granted EKS cluster-admin for `kubectl`. |
| `aws_region` | string | `us-east-1` | AWS region for all resources. |
| `state_key` | string | `terraform/eks-arc-runners/terraform.tfstate` | S3 state object key (1–1024 chars). |

### Networking

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `vpc_cidr` | string | `10.0.0.0/16` | IPv4 CIDR for the VPC. |
| `nat_gateway_count` | number | `1` | NAT gateways (1 = cost-saving, per-AZ = HA). |

### EKS cluster

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `kubernetes_version` | string | `1.36` | EKS minor version. One of 1.30–1.36. |
| `system_node_group_max_size` | number | `3` | Max nodes in the system node group. |

### Karpenter

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `karpenter_chart_version` | string | `1.13.0` | Exact Karpenter chart semver. |
| `karpenter_consolidate_after_seconds` | number | `30` | Empty-node consolidation delay (0–3600). |
| `nodepool_cpu_limit` | number | `100` | Max CPU cores the NodePool may provision. |
| `node_grace_period_seconds` | number | `300` | Runner node grace period (0–3600). |

### ARC controller & runner scale set

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `arc_controller_chart_version` | string | — (required) | Exact ARC controller chart semver (e.g. `0.10.1`). |
| `arc_namespace` | string | `arc-systems` | ARC controller namespace. |
| `arc_controller_ready_timeout_seconds` | number | `300` | Wait for controller readiness. |
| `runner_scale_set_chart_version` | string | — (required) | Exact runner-scale-set chart semver. |
| `runner_namespace` | string | `arc-runners` | Runner namespace. |
| `github_org` | string | — (required) | GitHub org for runner registration. |
| `runner_group` | string | `default` | GitHub runner group. |
| `runner_labels` | list(string) | — (required) | Scale-set labels (≥ 1). |
| `max_runners` | number | `10` | Max concurrent runners (1–1000). |
| `runner_cpu_request` | string | `1` | CPU request per runner pod. |
| `runner_memory_request` | string | `2Gi` | Memory request per runner pod. |

### GitHub App credentials (sensitive)

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `github_app_id` | string | — (required) | GitHub App ID (numeric string). |
| `github_app_installation_id` | string | — (required) | Installation ID (numeric string). |
| `github_app_private_key` | string | `""` | PEM private key (or use the file variant). |
| `github_app_private_key_file` | string | `""` | Path to the PEM file (read via `file()` in a local). |

### Secrets Store CSI Driver (optional path)

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `secrets_store_csi_chart_version` | string | `1.4.7` | CSI Driver chart semver. |
| `ascp_chart_version` | string | `0.3.11` | ASCP chart semver. |

> All chart-version variables require an exact `X.Y.Z` — ranges, wildcards, and
> floating tags (`latest`) are rejected at validation time.

## Destroy Procedure

```bash
terraform destroy
```

Terraform reverses the dependency order: runner scale set → ARC controller →
ESO resources → Karpenter NodePool (drains Karpenter nodes) → Karpenter
controller → secrets/KMS/IRSA → CSI driver → EKS → VPC.

### Karpenter node drain note

Removing the NodePool triggers Karpenter to drain and terminate its EC2 nodes;
the graph ensures EKS is not deleted until those nodes are gone. If nodes are
stuck:

```bash
kubectl get nodes -l karpenter.sh/nodepool=runners
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data --force
```

Re-run `terraform destroy` if it fails partway; it resumes from the last
successful deletion.

> The state bucket has `prevent_destroy` and is **not** removed by either
> `terraform destroy`. Delete it manually if you truly want it gone.

## CI

`.github/workflows/ci.yaml` runs on the self-hosted ARC scale set
(`runs-on: arc-runner-set`) and gates PRs to `main` with:

- `terraform fmt -check -recursive`
- `terraform validate` (with `-backend=false`)
- `terraform test`

The `terraform test` suite uses `mock_provider` + `override_module`, so it never
touches real AWS or the state bucket.

## Module Structure

```
eks-arc-platform/
├── versions.tf / backend.tf / providers.tf
├── variables.tf / locals.tf / main.tf / outputs.tf
├── backend.hcl(.example)         # backend bucket + assume-role config
├── terraform.tfvars(.example)    # variable values (gitignored)
├── s3-backend/                   # bootstrap: state bucket + IAM roles
├── .github/workflows/ci.yaml     # CI on the self-hosted runners
└── modules/
    ├── vpc/                      # VPC, AZ filtering, discovery tags
    ├── eks/                      # cluster, node group, addons, access entries
    ├── karpenter/                # IAM/SQS, Helm, NodePool+EC2NodeClass chart
    ├── secrets/                  # KMS, Secrets Manager, runner + ESO IRSA roles
    ├── external-secrets/         # ESO Helm + ClusterSecretStore/ExternalSecret chart
    ├── secrets-store-csi/        # CSI Driver + ASCP (optional)
    ├── arc-controller/           # ARC controller namespace + Helm
    └── runner-scale-set/         # runner Helm + listener tolerations
```

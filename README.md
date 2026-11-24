# AWS EKS Terraform Module

Reusable Terraform module for creating an **Amazon Elastic Kubernetes Service (EKS)** cluster in an **existing AWS VPC**, with an optional managed node group, hardened EC2 launch template, EKS API access entries, AWS-managed add-ons, and EBS CSI Pod Identity integration.

> **Validation status (25 November 2026):** A test deployment of **16 resources** completed (`16 added, 0 changed, 0 destroyed`) using Terraform **1.12.2**, AWS provider **6.73.0**, and Kubernetes **1.35**. Its managed node group was confirmed **ACTIVE** with no reported health issues. The test infrastructure was subsequently reported destroyed. The five add-ons were created by Terraform, but their final runtime health, Kubernetes node `Ready` state, and a PVC provisioning test were **not independently verified**. Do not treat this as full production certification.

## Features

- **Existing VPC selection** by VPC ID or `Name` tag; the module does not create network infrastructure.
- **Flexible subnet selection** via direct subnet IDs or private/public IDs and tag-based names.
- **Consistent uppercase naming** and mandatory organization tags overriding user-supplied tags.
- **Private EKS API endpoint** by default; optional public endpoint with CIDR restrictions.
- **EKS API authentication mode**, with optional IAM-role-based access entries and EKS access policies.
- **Cluster deletion protection** enabled by default.
- **Optional EKS secrets encryption** with a supplied customer-managed KMS key.
- **Managed node group** with configurable instance type, scaling, capacity, AMI type, and root disk.
- **Optional launch template** using encrypted EBS, IMDSv2 (`http_tokens = required`), and metadata hop limit of `1`.
- **AWS-managed EKS add-ons**: VPC CNI, CoreDNS, kube-proxy, EKS Pod Identity Agent, and Amazon EBS CSI Driver.
- **EBS CSI IAM role** bound to the driver using the add-on's `pod_identity_association` block.
- **Terraform outputs** for cluster identity, endpoint, IAM roles, node group, and launch template.

## Architecture

```text
Existing AWS VPC / existing subnets
           |
           v
EKS control plane (private endpoint by default)
  |-- Cluster IAM role + AmazonEKSClusterPolicy
  |-- API authentication + optional access entries
  |-- Optional existing KMS key for secrets
  |-- Deletion protection
  |
  +-- Optional managed EC2 node group
  |      |-- Worker IAM role + worker / ECR / optional CNI policies
  |      +-- Optional launch template (encrypted EBS, IMDSv2, hop limit 1)
  |
  +-- EKS-managed add-ons
         |-- VPC CNI
         |-- CoreDNS
         |-- kube-proxy
         |-- EKS Pod Identity Agent (when EBS CSI enabled)
         +-- EBS CSI Driver
                +-- Dedicated IAM role via Pod Identity association
```

**Out of scope:** VPCs, subnets, NAT gateways, routes, security group policy customization, private endpoint connectivity, applications, ingress controllers, observability stacks, and Kubernetes workload deployments.

## Requirements

| Component | Requirement |
|---|---|
| Terraform | `>= 1.12.0` |
| AWS provider | `>= 6.0, < 7.0` |
| AWS | Account permissions for EKS, EC2, IAM and optional KMS interactions |
| Networking | Existing compatible subnets in at least two Availability Zones; adequate IP capacity and worker egress or appropriate VPC endpoints |
| Runtime access | Network route to the private EKS API endpoint for `kubectl` |
| Recommended tooling | AWS CLI v2, `kubectl`, TFLint and Checkov |

Configure the AWS provider **in the root module**, not inside this reusable module. Use an AWS SSO profile or an appropriately scoped CI/CD IAM role; avoid long-lived static credentials.

## Quick start

Create a consuming root Terraform configuration:

```hcl
terraform {
  required_version = ">= 1.12.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0, < 7.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

module "eks" {
  # Pin a reviewed tag or commit SHA for production use.
  source = "git::https://github.com/CHERUKURIPRAVEEN/aws-eks-module.git?ref=master"

  application      = "Atf"
  application_code = "TF"
  environment      = "Dev"
  environment_code = "A1"
  cluster_number   = 1

  project     = "Ptf"
  backup      = "NonProd"
  owner       = "platform@veen.com"
  app_owner   = "platform@veen.com"
  description = "Development EKS cluster"

  # Choose exactly one of vpc_id and vpc_name.
  vpc_name = "MANAGEMENT_VPC"

  # Replace these placeholders with real subnets in separate AZs.
  subnet_ids = ["subnet-aaaaaaaaaaaaaaaaa", "subnet-bbbbbbbbbbbbbbbbb"]

  cluster_version         = "1.35"
  endpoint_private_access = true
  endpoint_public_access  = false

  # Deletion protection is on by default; false here is for a disposable test.
  enable_deletion_protection = false

  create_default_node_group = true
  node_group_instance_types = ["t3.medium"]
  node_group_capacity_type  = "ON_DEMAND"
  node_group_ami_type       = "AL2023_x86_64_STANDARD"
  node_group_min_size       = 1
  node_group_desired_size   = 2
  node_group_max_size       = 3
  node_group_disk_size      = 50
  enable_launch_template   = true

  enable_vpc_cni_addon    = true
  enable_coredns_addon    = true
  enable_kube_proxy_addon = true
  enable_ebs_csi_addon    = true

  tags = {
    managed_by  = "Terraform"
    cost_center = "CloudOps"
  }
}
```

> The current variable validation requires `owner` and `app_owner` to be `@veen.com` email addresses. Adapt the validation for your organization before adopting the module elsewhere. The example subnet IDs are placeholders; `ref=master` is for demonstration, not an immutable release reference. Kubernetes 1.35 is the **tested** version, not a promise of current availability in every Region.

Run from your consuming root project:

```bash
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

For **the module repository's own** test configuration, use `terraform plan -var-file=variables/test.tfvars -out=tfplan`; test settings, including deletion protection, should be inspected before applying. Store Terraform state in a secure remote backend with locking for shared deployments; never commit state, plan files, or credentials.

## Naming and organizational tags

Generated cluster name:

```text
UPPER(<environment>-<application_code>-<application>-<cluster_number padded to 2 digits>)
```

Example from the tested environment: `DEV-TF-ATF-01`. Associated names include `DEV-TF-ATF-01-NODE-ROLE`, `DEV-TF-ATF-01-NODES`, and `DEV-TF-ATF-01-NODES-LT`.

Mandatory tags are composed from `application`, `application_code`, `environment`, `environment_code`, `project`, `backup`, `owner`, `app_owner`, and `description`; these override conflicting entries in `tags`. Resource-specific `Name` tags override other `Name` values.

## Networking and subnet selection

Set **one** of `vpc_id` or `vpc_name`. An explicit nonempty `subnet_ids` list takes precedence over all private/public inputs. Otherwise the module selects private subnet IDs (or resolves private subnet names by `Name` tag), does the same for public subnets, and concatenates the lists.

```hcl
# Option A: explicit subnets
subnet_ids = ["subnet-aaaaaaaaaaaaaaaaa", "subnet-bbbbbbbbbbbbbbbbb"]

# Option B: lookup by Name tag in the chosen VPC
# private_subnet_names = ["app-private-a", "app-private-b"]

# Option C: explicit private subnet IDs
# private_subnet_ids = ["subnet-aaaaaaaaaaaaaaaaa", "subnet-bbbbbbbbbbbbbbbbb"]
```

**Important limits:** The module does not auto-discover suitable subnets, does not inspect route tables to prove a subnet is private, and does not currently enforce cross-VPC membership or multi-AZ placement for all selection methods. Validate VPC membership, two distinct AZs, routing, free addresses, NAT/VPC endpoint access, and cluster connectivity before production use. Additional subnet preconditions have been deferred to a future release.

## EKS access management

The cluster uses `authentication_mode = "API"` and currently enables bootstrap administrator permissions for the cluster creator. For production, plan a migration to a tightly scoped IAM Identity Center / SSO role; avoid dependence on an individual IAM user.

Use `access_entries` for additional IAM **roles** (defaults to `{}`):

```hcl
access_entries = {
  platform_view = {
    principal_arn = "arn:aws:iam::123456789012:role/ExistingPlatformViewRole"
    policy        = "AmazonEKSViewPolicy"
    scope         = "cluster"
  }
  team_edit = {
    principal_arn = "arn:aws:iam::123456789012:role/ExistingTeamRole"
    policy        = "AmazonEKSEditPolicy"
    scope         = "namespace"
    namespaces    = ["team-a"]
  }
}
```

Replace these **example role ARNs** with existing authorized roles. Supported policies are `AmazonEKSClusterAdminPolicy`, `AmazonEKSAdminPolicy`, `AmazonEKSEditPolicy`, and `AmazonEKSViewPolicy`; scope can be `cluster` or `namespace` (with at least one namespace for namespace scope). Access entries were defined in Terraform, but additional-role access was not tested with a real principal in the reported deployment.

## EKS managed add-ons and EBS CSI

| Add-on | Toggle | Optional version input | Default behavior |
|---|---|---|---|
| VPC CNI | `enable_vpc_cni_addon` | `vpc_cni_addon_version` | Enabled |
| CoreDNS | `enable_coredns_addon` | `coredns_addon_version` | Enabled |
| kube-proxy | `enable_kube_proxy_addon` | `kube_proxy_addon_version` | Enabled |
| EKS Pod Identity Agent | Coupled to `enable_ebs_csi_addon` | `pod_identity_agent_version` | Created when EBS CSI enabled |
| Amazon EBS CSI Driver | `enable_ebs_csi_addon` | `ebs_csi_addon_version` | Enabled |

When an add-on version input is `null`, AWS selects a compatible default; for controlled production upgrades, pin and validate compatible add-on versions. The module sets `bootstrap_self_managed_addons = false`, so managed add-ons must successfully initialize. Add-on conflicts are configured as `NONE` during create and `PRESERVE` during update.

The EBS CSI Driver uses a dedicated IAM role with `AmazonEBSCSIDriverPolicy` and an inline `pod_identity_association` for `ebs-csi-controller-sa`. The Pod Identity Agent must be running for this path to work. The VPC CNI policy currently attaches to the worker role by default; only disable `attach_cni_policy` after establishing a replacement credential mechanism.

If you disable the default node group, arrange external compute capacity before expecting CoreDNS, Pod Identity Agent, and EBS CSI pods to become healthy. Terraform resource creation alone does not prove an add-on is `ACTIVE`.

## Security and deletion protection

- EKS API endpoint is private-only by default (`endpoint_private_access = true`, `endpoint_public_access = false`).
- Launch template root EBS volumes are encrypted, with optional customer KMS key; EC2 metadata requires IMDSv2 and a response hop limit of 1.
- Cluster secrets encryption may use an **existing** customer-managed key when `enable_cluster_kms_encryption = true` and `cluster_kms_key_arn` is set. Confirm AWS-managed encryption behavior separately for your Kubernetes version.
- `enable_deletion_protection = true` by default. To delete a protected cluster, first set the value to `false` and **apply that change**, then run destroy after reviewing the plan.
- The module does **not** currently configure EKS control-plane log types or CloudWatch retention. Enable logging and retention through a future module update or approved external configuration before production.

Example controlled teardown from the module repository:

```bash
# First set enable_deletion_protection=false in test.tfvars and apply it:
terraform plan -var-file=variables/test.tfvars -out=tfplan
terraform apply tfplan

# Then review the destruction plan and apply only if intended:
terraform plan -destroy -var-file=variables/test.tfvars -out=destroy.tfplan
terraform apply destroy.tfplan
```

## Outputs

| Output | Description |
|---|---|
| `cluster_id` / `cluster_name` / `cluster_arn` | EKS identity |
| `cluster_endpoint` / `cluster_version` | Kubernetes API endpoint and version |
| `cluster_security_group_id` | AWS-created EKS cluster security group |
| `cluster_iam_role_arn` | Cluster IAM role |
| `node_group_id` / `node_group_role_arn` | Managed node group values, or `null` if disabled |
| `launch_template_id` / `launch_template_version` | Launch template values, or `null` if disabled |

## Validation and CI

```bash
terraform fmt -check -recursive
terraform validate
tflint --recursive
checkov -d . --framework terraform --skip-path aws/dist --skip-check CKV_AWS_37
```

**Reported CI scan:** Checkov `3.4.10` found **30 passed, 0 failed** among enabled checks. `CKV_AWS_37` was explicitly excluded; zero “Skipped checks” in that output does **not** mean no checks were excluded. Document and periodically reassess this exception. Checkov passing does not replace runtime, IAM, networking, or penetration testing.

**Reported test:** On 25 November 2026 (IST), Terraform successfully applied **16 new resources** for `DEV-TF-ATF-01` (EKS Kubernetes `1.35`), and the managed node group was confirmed `ACTIVE` with `health.issues = []`. The five add-on resources, including EBS CSI, completed Terraform creation. The cluster was later reported destroyed.

### Runtime checks for the next test deployment

```bash
CLUSTER=DEV-TF-ATF-01
REGION=us-east-1

aws eks describe-cluster --name "$CLUSTER" --region "$REGION" \
  --query 'cluster.{Status:status,Version:version,Health:health.issues}'
aws eks describe-nodegroup --cluster-name "$CLUSTER" \
  --nodegroup-name "${CLUSTER}-NODES" --region "$REGION" \
  --query 'nodegroup.{Status:status,Issues:health.issues}'

for addon in vpc-cni coredns kube-proxy eks-pod-identity-agent aws-ebs-csi-driver; do
  aws eks describe-addon --cluster-name "$CLUSTER" \
    --addon-name "$addon" --region "$REGION" \
    --query 'addon.{Name:addonName,Status:status,Issues:health.issues}'
done

# Requires an authorized IAM identity and private network connectivity:
aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION"
kubectl get nodes -o wide
kubectl get pods -n kube-system
```

Require all relevant add-ons to report `ACTIVE`, worker nodes to report `Ready`, and an actual test PVC to bind and mount before signing off on production storage readiness. After deployment, rerun `terraform plan` with the same variable file and confirm **no changes**.

## Known limitations and release checklist

- Subnet membership, distinct AZ placement, and routing are not enforced comprehensively in Terraform.
- Cluster creator bootstraps as an admin; the recommended production SSO access pattern needs additional validation.
- Additional access entries require a real IAM role integration test.
- Add-on versions default to AWS-selected values unless pinned.
- EBS CSI PVC provisioning and add-on `ACTIVE` health were not verified in the reported test.
- Control-plane logging, log retention, and deeper operational monitoring are not implemented here.
- IAM security boundaries, multi-account CI/CD access, remote state and DR procedures remain the caller's responsibility.
- Update the documentation, verify source code/variables, rerun TFLint and Checkov, test in an isolated AWS account, and tag an immutable version only after reviewing unresolved limitations.

## Maintainer

Praveen Cherukuri | DevOps Engineer

Repository: https://github.com/CHERUKURIPRAVEEN/aws-eks-module

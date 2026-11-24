# AWS EKS Terraform Module

Reusable Terraform module for provisioning an **Amazon Elastic Kubernetes Service (EKS) cluster** in an **existing VPC**, with an optional **EKS managed node group**, optional **EC2 launch template**, configurable networking, IAM roles, organizational tagging, and encryption settings.

> **Implementation status:** The repository implements the features documented below. A test deployment was reported successful using Terraform 1.12.2 and AWS provider 6.73.0 (`9 added, 0 changed, 0 destroyed`). This does **not** establish production readiness or Kubernetes workload health. Read [Current limitations and roadmap](#current-limitations-and-roadmap) before production use.

## Features

- **Existing VPC selection:** Specify either `vpc_id` or `vpc_name` (matched against the AWS `Name` tag).
- **Existing subnet selection:** Provide a direct list of subnet IDs, or combine private/public subnet IDs and/or Name-tag lookups.
- **Deterministic uppercase names:** Cluster, roles, node group, and launch template use a consistent naming convention.
- **Mandatory organization tags:** Caller-supplied `tags` are merged, with mandatory tags taking precedence.
- **EKS cluster configuration:** Optional Kubernetes version, private/public API endpoint switches, and optional customer-managed KMS encryption of Kubernetes secrets.
- **IAM roles:** Separate EKS control plane and EC2 worker roles, with AWS-managed policy attachments.
- **Optional default managed node group:** Configure instance types, capacity type, AMI family, disk size, and scaling boundaries.
- **Optional EC2 launch template:** Encrypted EBS root volume, GP2/GP3 option, optional KMS key, required IMDSv2, response hop limit **1**, instance/volume tags, and optional detailed monitoring.
- **Optional worker CNI policy attachment:** Can be disabled when AWS VPC CNI credentials are supplied through a separate mechanism.
- **Terraform outputs:** Cluster identity, endpoint, security group, IAM roles, node group, and launch template identifiers.

## Architecture

```text
Existing AWS VPC
  └── Existing subnets (at least two suitable subnets recommended)
        ├── EKS control plane
        │     ├── EKS cluster IAM role
        │     └── Optional customer-managed secrets KMS key
        └── Optional EKS managed node group
              ├── EC2 worker IAM role + policy attachments
              └── Optional EC2 launch template
                    ├── IMDSv2 (required; response hop limit 1)
                    ├── Encrypted root EBS volume (GP3 by default)
                    └── EC2 instance / volume tags
```

**Scope:** This module **does not create a VPC, subnets, NAT gateways, route tables, VPN, or VPC endpoints**. Network configuration and private endpoint connectivity must exist before deployment.

## Requirements

| Component | Requirement |
|---|---|
| Terraform CLI | `>= 1.12.0` |
| Terraform AWS provider | `>= 6.0, < 7.0` |
| AWS account | IAM permission to create EKS, IAM roles/policy attachments, managed node groups, and optionally EC2 launch templates |
| Networking | Existing VPC and appropriately routed subnets in the target AWS Region |
| Access | Configured AWS credentials in the **root module** (for example, AWS SSO or CI/CD role federation) |
| Optional tools | AWS CLI and `kubectl` for post-deployment checks; Checkov for policy scans |

The module declares provider **requirements** but does not configure credentials or a provider region. Configure the AWS provider in your root Terraform project.

## Quick start

Example root module (`main.tf`):

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
  source = "git::https://github.com/CHERUKURIPRAVEEN/aws-eks-module.git?ref=master"

  application      = "Atf"
  application_code = "TF"
  environment      = "Dev"
  environment_code = "A1"
  cluster_number   = 1
  project          = "Ptf"
  backup           = "NonProd"
  owner            = "platform@veen.com"
  app_owner        = "platform@veen.com"
  description      = "Terraform EKS module example environment"

  # Choose exactly one: vpc_id OR vpc_name.
  vpc_name = "MANAGEMENT_VPC"

  # Replace with two or more existing, compatible subnet IDs.
  subnet_ids = ["subnet-aaaaaaaaaaaaaaaaa", "subnet-bbbbbbbbbbbbbbbbb"]

  # Pin a supported version approved for your environment.
  # The current module allows null (AWS selects its default).
  cluster_version = "1.37"

  endpoint_private_access = true
  endpoint_public_access  = false

  create_default_node_group = true
  node_group_instance_types = ["t3.medium"]
  node_group_capacity_type  = "ON_DEMAND"
  node_group_min_size       = 1
  node_group_desired_size   = 2
  node_group_max_size       = 3
  node_group_disk_size      = 50
  node_group_ami_type       = "AL2023_x86_64_STANDARD"

  enable_launch_template         = true
  node_group_volume_type         = "gp3"
  enable_node_detailed_monitoring = false

  tags = {
    managed_by  = "Terraform"
    cost_center = "CloudOps"
  }
}
```

> **Important:** The email validation in the current repository requires `owner` and `app_owner` to end in `@veen.com`. Modify this validation in your fork if your organization uses another email domain. The subnet IDs above are placeholders.
>
> For repeatable releases, replace `ref=master` with a tested immutable Git tag or commit SHA.

Deploy from the **root Terraform directory**:

```bash
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

To use this repository's existing test values when executing Terraform **from the module repository itself**:

```bash
terraform init
terraform validate
terraform plan -var-file="variables/test.tfvars" -out=tfplan
terraform apply tfplan
```

Do **not** commit `tfplan`, state files, or credentials. Use a secure remote Terraform backend with locking for shared environments.

## Networking and subnet selection

The module resolves the target VPC from either `vpc_id` or `vpc_name`. **Exactly one must be specified.** It does not create networking resources.

Subnet precedence:

1. When `subnet_ids` is nonempty, it is used directly for **both** the EKS control plane and default node group.
2. Otherwise, `private_subnet_ids` is used when set; otherwise the module resolves `private_subnet_names` by `Name` tag in the selected VPC.
3. Similarly, `public_subnet_ids` is used when set; otherwise the module resolves `public_subnet_names`.
4. The selected private and public subnet lists are concatenated.

Examples:

```hcl
# Direct selection: takes precedence over private/public inputs
subnet_ids = ["subnet-aaaaaaaaaaaaaaaaa", "subnet-bbbbbbbbbbbbbbbbb"]
```

```hcl
# Name-based selection (Name tags must match exactly and resolve uniquely)
private_subnet_names = ["app-private-az1", "app-private-az2"]
```

```hcl
# Mixed explicit IDs
private_subnet_ids = ["subnet-aaaaaaaaaaaaaaaaa", "subnet-bbbbbbbbbbbbbbbbb"]
public_subnet_ids  = []
```

**Caveats:**

- `private` and `public` in the input names are caller-declared labels; this module does **not** inspect route tables to classify subnets automatically.
- It does **not** discover subnets automatically when all subnet inputs are empty.
- The currently committed code validates direct `subnet_ids` format, uniqueness, and nonempty-list minimum count, but does not enforce cross-VPC membership or multi-AZ placement for every subnet selection method.
- For production, verify **at least two Availability Zones**, subnet routing, IP capacity, EKS service requirements, and worker outbound connectivity. Prefer private worker subnets.
- An EKS private-only API endpoint requires network reachability (VPN, Direct Connect, bastion, VPC-connected runner, etc.) for `kubectl`.

## Kubernetes version management

Set `cluster_version` to the EKS-supported Kubernetes version approved for your deployment:

```hcl
cluster_version = "1.37"
```

**Current implementation:** `cluster_version` defaults to `null`; when omitted, EKS selects the version used at creation. The managed node group currently does **not** set its `version` argument explicitly. EKS manages the initial compatible node version, but coordinated node-group upgrades must be checked and planned deliberately.

To upgrade an existing cluster:

1. Check EKS support for the desired version in your Region and confirm add-on/workload compatibility.
2. Update `cluster_version` by **one supported minor-version increment**.
3. Review the Terraform plan and upgrade the control plane.
4. Upgrade/verify node groups and managed add-ons separately as appropriate.
5. Validate node readiness, application availability, and rollback/recovery plans.

Kubernetes minor-version **downgrades are not supported** by EKS. Do not change `cluster_version` in an existing environment without an approved upgrade procedure.

## Optional managed node group

| Setting | Description | Default |
|---|---|---|
| `create_default_node_group` | Create module-managed node group and its IAM resources | `true` |
| `node_group_name` | Override generated node group name | `null` (generated) |
| `node_group_instance_types` | Worker EC2 types | `["t3.medium"]` |
| `node_group_capacity_type` | `ON_DEMAND` or `SPOT` | `ON_DEMAND` |
| `node_group_ami_type` | Supported Amazon Linux 2023 EKS AMI type | `AL2023_x86_64_STANDARD` |
| `node_group_min_size` | Minimum node count | `1` |
| `node_group_desired_size` | Desired node count | `2` |
| `node_group_max_size` | Maximum node count | `3` |
| `node_group_disk_size` | Root disk in GiB | `50` |
| `attach_cni_policy` | Attach `AmazonEKS_CNI_Policy` to worker role | `true` |

To create only the cluster and its cluster IAM resources:

```hcl
create_default_node_group = false
```

Setting this to `false` **after deployment will plan the destruction of this module's managed node group and associated resources**. Treat this as a potentially disruptive operation.

The worker role is granted the AWS-managed `AmazonEKSWorkerNodePolicy` and `AmazonEC2ContainerRegistryPullOnly` policies; the VPC CNI policy attachment is optional. Node group creation has explicit dependencies on these attachments.

## Optional EC2 launch template

A custom launch template is created only when **both** are true:

```hcl
create_default_node_group = true
enable_launch_template   = true
```

| Setting | Behavior | Default |
|---|---|---|
| `enable_launch_template` | Create custom EC2 launch template | `true` |
| `node_group_volume_type` | `gp2` or `gp3` root EBS volume | `gp3` |
| `node_group_disk_size` | Root EBS volume size | `50` GiB |
| `node_group_volume_kms_key_arn` | Optional customer-managed EBS KMS key | `null` |
| `enable_node_detailed_monitoring` | EC2 detailed monitoring | `false` |

When enabled, the custom launch template specifies:

- Encrypted root EBS volume (`/dev/xvda`), delete on termination.
- IMDSv2 required (`http_tokens = "required"`).
- `http_put_response_hop_limit = 1` (addresses Checkov `CKV_AWS_341`).
- Instance metadata tags disabled.
- Mandatory/custom tags for the launch template, EC2 instances, and EBS volumes.

When disabled, the managed node group is created without a custom launch template and uses `node_group_disk_size` directly. **Do not assume all launch-template security settings are enforced in that mode.**

**Operational notes:** A hop limit of 1 can affect software inside containers that relies on direct IMDS; use EKS Pod Identity or IRSA instead. A customer-managed EBS KMS key requires appropriate permissions for the EC2 Auto Scaling service-linked role. Changing launch template usage for an existing node group may require replacement; always inspect the plan.

## EKS API access and encryption

API endpoint defaults:

```hcl
endpoint_private_access = true
endpoint_public_access  = false
public_access_cidrs     = []
```

When enabling a public endpoint, explicitly supply **restricted** CIDR ranges permitted for your organization; verify access in the AWS console and Terraform plan. The current repository does not enforce non-open CIDR validation.

Optional customer-managed KMS encryption for Kubernetes secrets:

```hcl
enable_cluster_kms_encryption = true
cluster_kms_key_arn           = "arn:aws:kms:us-east-1:123456789012:key/REPLACE-ME"
```

The KMS key must already exist, and its policy must allow the necessary EKS operations. This module does not create KMS keys. AWS may provide default EKS secrets encryption independently of this optional customer-managed setting.

## Naming and tagging

The cluster naming pattern is:

```text
UPPER(ENVIRONMENT-ENVIRONMENT_CODE-APPLICATION_CODE-APPLICATION-NN)
```

With example inputs (`Dev`, `A1`, `TF`, `Atf`, `1`), the names are:

| Resource | Example generated name |
|---|---|
| EKS cluster | `DEV-A1-TF-ATF-01` |
| Cluster IAM role | `DEV-A1-TF-ATF-01-CLUSTER-ROLE` |
| Worker IAM role | `DEV-A1-TF-ATF-01-NODE-ROLE` |
| Default node group | `DEV-A1-TF-ATF-01-NODES` |
| Launch template | `DEV-A1-TF-ATF-01-NODES-LT` |
| Worker EC2 instance Name tag | `DEV-A1-TF-ATF-01-NODES` |
| Root EBS Name tag | `DEV-A1-TF-ATF-01-NODES-EBS` |

Mandatory tags: `application`, `application_code`, `environment`, `environment_code`, `project`, `backup`, `owner`, `app_owner`, and `description`. Resource-specific `Name` tags are also applied. Values in `tags` cannot override these mandatory keys.

## Inputs

The tables below reflect the currently committed `variables.tf` on `master` (November 2026).

### Organization and naming

| Variable | Type | Required | Default / rules |
|---|---|---|---|
| `application` | `string` | Yes | Max 7 characters |
| `application_code` | `string` | Yes | Max 3 characters |
| `environment` | `string` | No | `Dev`; choices: `Dev`, `Qa`, `Stage`, `PreProd`, `Production` |
| `environment_code` | `string` | No | `A1`; exactly 2 characters |
| `cluster_number` | `number` | No | `1`; between 1 and 99 |
| `project` | `string` | No | `""`; max 7 characters |
| `owner` | `string` | Yes | Must match `@veen.com` email validation |
| `app_owner` | `string` | Yes | Must match `@veen.com` email validation |
| `backup` | `string` | No | `N/A`; `N/A`, `NonProd`, or `Prod` |
| `description` | `string` | Yes | At least 10 characters |
| `tags` | `map(string)` | No | `{ env = "NP" }` |

### VPC and subnets

| Variable | Type | Default |
|---|---|---|
| `vpc_id` | `string` | `null` |
| `vpc_name` | `string` | `null` |
| `subnet_ids` | `list(string)` | `[]` |
| `private_subnet_ids` | `list(string)` | `[]` |
| `private_subnet_names` | `list(string)` | `[]` |
| `public_subnet_ids` | `list(string)` | `[]` |
| `public_subnet_names` | `list(string)` | `[]` |

### Cluster and endpoint

| Variable | Type | Default |
|---|---|---|
| `cluster_version` | `string` | `null` |
| `endpoint_private_access` | `bool` | `true` |
| `endpoint_public_access` | `bool` | `false` |
| `public_access_cidrs` | `list(string)` | `[]` |
| `enable_cluster_kms_encryption` | `bool` | `false` |
| `cluster_kms_key_arn` | `string` | `null` |

### Node group and launch template

| Variable | Type | Default |
|---|---|---|
| `create_default_node_group` | `bool` | `true` |
| `node_group_name` | `string` | `null` |
| `node_group_instance_types` | `list(string)` | `["t3.medium"]` |
| `node_group_capacity_type` | `string` | `ON_DEMAND` |
| `node_group_ami_type` | `string` | `AL2023_x86_64_STANDARD` |
| `node_group_min_size` | `number` | `1` |
| `node_group_desired_size` | `number` | `2` |
| `node_group_max_size` | `number` | `3` |
| `node_group_disk_size` | `number` | `50` |
| `attach_cni_policy` | `bool` | `true` |
| `enable_launch_template` | `bool` | `true` |
| `node_group_volume_type` | `string` | `gp3` |
| `node_group_volume_kms_key_arn` | `string` | `null` |
| `enable_node_detailed_monitoring` | `bool` | `false` |

## Outputs

| Output | Description |
|---|---|
| `cluster_id` | EKS cluster ID |
| `cluster_name` | EKS cluster name |
| `cluster_arn` | EKS cluster ARN |
| `cluster_endpoint` | Kubernetes API endpoint |
| `cluster_version` | Effective EKS Kubernetes version |
| `cluster_security_group_id` | EKS-created cluster security group ID |
| `cluster_iam_role_arn` | Cluster IAM role ARN |
| `node_group_id` | Managed node group ID, or `null` if disabled |
| `node_group_role_arn` | Node group IAM role ARN, or `null` if disabled |
| `launch_template_id` | Launch template ID, or `null` if disabled |
| `launch_template_version` | Launch template latest version, or `null` if disabled |

Root module example:

```hcl
output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}
```

## Validation scenarios

The following counts were verified in user-provided Terraform plan output for a new test environment, with optional logging/additional resources absent and CNI policy attachment enabled:

| `create_default_node_group` | `enable_launch_template` | Expected creates |
|---|---|---:|
| `false` | Either | 3 |
| `true` | `false` | 8 |
| `true` | `true` | 9 |

The nine-resource scenario was also reported successfully applied. Counts change depending on existing Terraform state and future module features.

Examples when running Terraform **within the module repository**, with the included `variables/test.tfvars`:

```bash
terraform plan -var-file=variables/test.tfvars \
  -var='create_default_node_group=true' \
  -var='enable_launch_template=true'

terraform plan -var-file=variables/test.tfvars \
  -var='create_default_node_group=true' \
  -var='enable_launch_template=false'

terraform plan -var-file=variables/test.tfvars \
  -var='create_default_node_group=false'
```

**WARNING:** If resources already exist in the current state, switching flags can show **destructive** changes instead of the fresh-create counts. Never apply toggle-based test plans to an existing production environment without reviewing the full diff.

Static checks:

```bash
terraform fmt -check -recursive
terraform validate
checkov -d . --framework terraform
```

## Post-deployment checks

Replace `CLUSTER_NAME` and `NODE_GROUP_NAME` if you customized the generated names:

```bash
aws eks describe-cluster \
  --region us-east-1 \
  --name DEV-A1-TF-ATF-01 \
  --query 'cluster.{Name:name,Version:version,Status:status}'

aws eks describe-nodegroup \
  --region us-east-1 \
  --cluster-name DEV-A1-TF-ATF-01 \
  --nodegroup-name DEV-A1-TF-ATF-01-NODES \
  --query 'nodegroup.{Status:status,Health:health.issues}'

aws eks update-kubeconfig \
  --region us-east-1 \
  --name DEV-A1-TF-ATF-01

kubectl get nodes -o wide
kubectl get pods -A
```

With `endpoint_public_access = false`, run `kubectl` from a machine with private VPC reachability and a principal authorized for Kubernetes access. Successful `terraform apply` alone does not prove nodes are `Ready` or that the current operator can use `kubectl`.

Check for drift after apply:

```bash
terraform plan
```

If you originally applied using a `.tfvars` file, use **the same inputs** when checking drift:

```bash
terraform plan -var-file=variables/test.tfvars
```

## Current limitations and roadmap

The following are **not implemented** in the current committed module and should not be inferred from a successful apply:

- Terraform-managed **EKS access entries** and IAM identity-to-Kubernetes access policy associations.
- Terraform-managed **EKS add-ons** (for example, VPC CNI, CoreDNS, kube-proxy) with explicit version management.
- An explicit **cluster deletion protection** setting.
- **EKS control plane CloudWatch log group/log type management** and retention configuration.
- Automatic subnet discovery or route-table-based public/private subnet detection.
- Enforced validation that all selected subnets belong to the VPC and span two Availability Zones.
- A blocking scaling invariant: the existing `check "node_group_scaling"` emits a warning rather than preventing apply.
- Explicit node group Kubernetes version pinning in `aws_eks_node_group`.
- Automated monitoring, autoscaling add-ons, workload deployment, disaster recovery, or application-level security controls.

### Production considerations

1. Ensure a secure remote state backend, state locking, least-privilege deployment role, and CI policy checks.
2. Validate subnet and network prerequisites (including node-to-EKS communication, ECR access, DNS, NAT or appropriate VPC endpoints).
3. Configure access entries / administrative access explicitly and test private API endpoint reachability.
4. Establish logging, add-on lifecycle management, alerts, backups, and upgrade procedures.
5. Review the effect of modifying `cluster_version`, `create_default_node_group`, `enable_launch_template`, and KMS settings in an existing state before applying.
6. Do not interpret the AWS provider's tolerated legacy SDK warnings as security findings; investigate any drift or failed operations separately.

## Destruction

Only destroy **disposable test environments** after reviewing the plan:

```bash
terraform plan -destroy -var-file=variables/test.tfvars
terraform destroy -var-file=variables/test.tfvars
```

Destruction may delete managed worker nodes and the EKS control plane, causing service outages and data loss for workloads. This module does not create or destroy the shared VPC/subnets.

## Repository

Source: <https://github.com/CHERUKURIPRAVEEN/aws-eks-module>

Maintained by **Praveen Cherukuri**.
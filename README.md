# AWS EKS Terraform Module

A reusable and production-oriented Terraform module for creating an **Amazon EKS cluster with an AWS Managed Node Group** using an existing VPC and existing subnets.

The module is designed with strong input validation, flexible VPC selection, subnet validation, configurable Kubernetes versions, and configurable managed node group settings.

---

## Features

* Create an Amazon EKS cluster
* Create an EKS Managed Node Group
* Use an existing VPC
* Support VPC selection by:

  * VPC ID
  * VPC Name
* Use existing subnet IDs
* Require a minimum of two subnets
* Validate subnet IDs
* Prevent duplicate subnet IDs
* Configure Kubernetes cluster version
* Configure managed node group:

  * Instance types
  * Capacity type
  * Minimum size
  * Desired size
  * Maximum size
  * Disk size
  * AMI type
* Strong Terraform variable validation
* Support common organizational tags
* Designed for reuse across environments

---

## Architecture

The module creates the following AWS resources:

```text
                         ┌──────────────────────────┐
                         │       Existing VPC       │
                         │                          │
                         │  ┌────────────────────┐  │
                         │  │   Private/Public   │  │
                         │  │      Subnets       │  │
                         │  └─────────┬──────────┘  │
                         │            │             │
                         └────────────┼─────────────┘
                                      │
                                      ▼
                         ┌──────────────────────────┐
                         │       EKS Cluster        │
                         │                          │
                         │     Kubernetes API       │
                         └────────────┬─────────────┘
                                      │
                                      ▼
                         ┌──────────────────────────┐
                         │   Managed Node Group     │
                         │                          │
                         │  EC2 Worker Nodes        │
                         │  t3.medium / custom      │
                         └──────────────────────────┘
```

---

## Module Scope

This module intentionally focuses on the core EKS components:

```text
EKS Cluster
     │
     ├── Mandatory IAM Role
     │
     └── Managed Node Group
              │
              └── EC2 Worker Nodes
```

Networking resources such as the VPC and subnets are expected to already exist.

---

# Requirements

| Name         | Version  |
| ------------ | -------- |
| Terraform    | >= 1.5.0 |
| AWS Provider | >= 5.0   |
| AWS Account  | Required |

The AWS account must have sufficient permissions to create EKS clusters, IAM roles/policies, and managed node groups.

---

# AWS Services

This module uses the following AWS services:

* Amazon EKS
* Amazon EC2
* Amazon IAM
* Amazon VPC

---

# Usage

## Basic Usage

```hcl
module "eks" {
  source = "git::https://github.com/CHERUKURIPRAVEEN/aws-eks-module.git"

  region = "us-east-1"

  application      = "EKSAPP"
  application_code = "EKS"

  environment      = "Dev"
  environment_code = "A1"

  project     = "EKS"
  owner       = "devops@veen.com"
  app_owner   = "appowner@veen.com"
  backup      = "NonProd"
  description = "EKS cluster test environment"

  vpc_id = "vpc-0123456789abcdef0"

  subnet_ids = [
    "subnet-0123456789abcdef0",
    "subnet-0123456789abcdef1"
  ]

  cluster_name    = "test-eks-cluster"
  cluster_version = "1.33"

  node_group_name = "test-eks-ng"

  node_group_instance_types = [
    "t3.medium"
  ]

  node_group_capacity_type = "ON_DEMAND"

  node_group_min_size     = 1
  node_group_desired_size = 2
  node_group_max_size     = 3

  node_group_disk_size = 50

  node_group_ami_type = "AL2023_x86_64_STANDARD"
}
```

---

# Provider Configuration

The AWS provider should be configured in the root module.

```hcl
provider "aws" {
  region = var.region
}
```

---

# Input Variables

## Common Variables

### `region`

AWS region where the EKS cluster will be created.

```hcl
region = "us-east-1"
```

**Type:**

```text
string
```

**Default:**

```text
"us-east-1"
```

---

### `application`

Application name used for tagging and resource identification.

Maximum length: **7 characters**.

```hcl
application = "EKSAPP"
```

**Type:**

```text
string
```

---

### `application_code`

Application code used for resource identification and tagging.

Maximum length: **3 characters**.

```hcl
application_code = "EKS"
```

**Type:**

```text
string
```

---

### `environment`

Environment in which the EKS cluster is deployed.

Supported values:

```text
Dev
Qa
Stage
PreProd
Production
```

Example:

```hcl
environment = "Dev"
```

**Type:**

```text
string
```

**Default:**

```text
"Dev"
```

---

### `environment_code`

Two-character environment code.

Examples:

```text
A1
S1
S2
SX
P1
P2
PX
PR
PD
```

Example:

```hcl
environment_code = "A1"
```

**Type:**

```text
string
```

**Default:**

```text
"A1"
```

---

### `tags`

Additional tags to be applied to resources.

Example:

```hcl
tags = {
  env = "NP"
}
```

**Type:**

```text
map(string)
```

**Default:**

```hcl
{
  env = "NP"
}
```

---

### `project`

Project name associated with the EKS cluster.

Maximum length: **7 characters**.

```hcl
project = "EKS"
```

**Type:**

```text
string
```

**Default:**

```text
""
```

---

### `owner`

Email address of the EKS cluster owner.

The value must use the organization's `@veen.com` domain.

Example:

```hcl
owner = "devops@veen.com"
```

**Type:**

```text
string
```

---

### `app_owner`

Email address of the application owner.

The value must use the organization's `@veen.com` domain.

Example:

```hcl
app_owner = "appowner@veen.com"
```

**Type:**

```text
string
```

---

### `backup`

Backup classification for the EKS cluster.

Supported values:

```text
N/A
NonProd
Prod
```

Example:

```hcl
backup = "NonProd"
```

**Type:**

```text
string
```

**Default:**

```text
"N/A"
```

---

### `description`

Description associated with the EKS cluster.

Minimum length: **10 characters**.

Example:

```hcl
description = "EKS cluster test environment"
```

**Type:**

```text
string
```

---

# VPC Variables

## `vpc_id`

Existing VPC ID to use for the EKS cluster.

Example:

```hcl
vpc_id = "vpc-0123456789abcdef0"
```

**Type:**

```text
string
```

**Default:**

```text
null
```

The value must match the AWS VPC ID format:

```text
vpc-xxxxxxxxxxxxxxxxx
```

---

## `vpc_name`

Existing VPC Name tag used to identify the VPC.

Example:

```hcl
vpc_name = "TF_VPC"
```

**Type:**

```text
string
```

**Default:**

```text
null
```

---

## `required_vpc_name`

Predefined VPC name used for VPC discovery.

Supported values:

```text
MANAGEMENT_VPC
DEV_VPC
STAGE_VPC
PREPROD_VPC
PRODUCTION_VPC
TF_VPC
```

Example:

```hcl
required_vpc_name = "TF_VPC"
```

**Type:**

```text
string
```

**Default:**

```text
"MANAGEMENT_VPC"
```

---

# Subnet Variables

## `subnet_ids`

List of existing subnet IDs to use for the EKS cluster and managed node group.

At least **two subnet IDs** must be provided.

Example:

```hcl
subnet_ids = [
  "subnet-0123456789abcdef0",
  "subnet-0123456789abcdef1"
]
```

**Type:**

```text
list(string)
```

The module validates:

* At least two subnets are provided
* Every subnet ID follows the AWS subnet ID format
* Duplicate subnet IDs are not allowed

Valid format:

```text
subnet-xxxxxxxxxxxxxxxxx
```

---

# EKS Cluster Variables

## `cluster_name`

Name of the EKS cluster.

Example:

```hcl
cluster_name = "test-eks-cluster"
```

**Type:**

```text
string
```

The value must not be empty.

---

## `cluster_version`

Kubernetes version for the EKS cluster.

Example:

```hcl
cluster_version = "1.33"
```

**Type:**

```text
string
```

**Default:**

```text
null
```

The expected format is:

```text
MAJOR.MINOR
```

Examples:

```text
1.31
1.32
1.33
```

If `null` is provided, the AWS provider/EKS service default behavior is used.

---

# Managed Node Group Variables

## `node_group_name`

Name of the EKS managed node group.

Example:

```hcl
node_group_name = "test-eks-ng"
```

**Type:**

```text
string
```

**Default:**

```text
null
```

If provided, the value must not be empty.

---

## `node_group_instance_types`

EC2 instance types used by the managed node group.

Example:

```hcl
node_group_instance_types = [
  "t3.medium"
]
```

Multiple instance types can be supplied:

```hcl
node_group_instance_types = [
  "t3.medium",
  "t3.large"
]
```

**Type:**

```text
list(string)
```

**Default:**

```hcl
[
  "t3.medium"
]
```

At least one instance type must be provided.

---

## `node_group_capacity_type`

Capacity type for the managed node group.

Supported values:

```text
ON_DEMAND
SPOT
```

Example:

```hcl
node_group_capacity_type = "ON_DEMAND"
```

**Type:**

```text
string
```

**Default:**

```text
"ON_DEMAND"
```

### ON_DEMAND

Recommended when predictable availability and stability are more important than cost optimization.

### SPOT

Recommended for workloads that can tolerate interruptions and are optimized for cost.

---

## `node_group_min_size`

Minimum number of nodes in the managed node group.

Example:

```hcl
node_group_min_size = 1
```

**Type:**

```text
number
```

**Default:**

```text
1
```

Minimum allowed value:

```text
0
```

---

## `node_group_desired_size`

Desired number of nodes in the managed node group.

Example:

```hcl
node_group_desired_size = 2
```

**Type:**

```text
number
```

**Default:**

```text
2
```

Minimum allowed value:

```text
1
```

---

## `node_group_max_size`

Maximum number of nodes in the managed node group.

Example:

```hcl
node_group_max_size = 3
```

**Type:**

```text
number
```

**Default:**

```text
3
```

Minimum allowed value:

```text
1
```

---

## `node_group_disk_size`

Root EBS volume size for worker nodes.

Example:

```hcl
node_group_disk_size = 50
```

**Type:**

```text
number
```

**Default:**

```text
50
```

Minimum allowed value:

```text
20 GiB
```

---

## `node_group_ami_type`

AMI type used by the managed node group.

Supported values:

```text
AL2023_x86_64_STANDARD
AL2023_ARM_64_STANDARD
AL2023_x86_64_NVIDIA
AL2023_x86_64_NEURON
```

Example:

```hcl
node_group_ami_type = "AL2023_x86_64_STANDARD"
```

**Type:**

```text
string
```

**Default:**

```text
"AL2023_x86_64_STANDARD"
```

---

# Complete `test.tfvars`

The following configuration can be used as a starting point for testing.

```hcl
#--------------------------------------------------COMMON Variables-------------------------------------------------#

region = "us-east-1"

application = "EKSAPP"

application_code = "EKS"

environment = "Dev"

environment_code = "A1"

tags = {
  env = "NP"
}

project = "EKS"

owner = "devops@veen.com"

app_owner = "appowner@veen.com"

backup = "NonProd"

description = "EKS cluster test environment"


#--------------------------------------------------VPC Variables-------------------------------------------------#

vpc_id = "vpc-0123456789abcdef0"

vpc_name = null

required_vpc_name = "TF_VPC"


#--------------------------------------------------Subnet Variables-------------------------------------------------#

subnet_ids = [
  "subnet-0123456789abcdef0",
  "subnet-0123456789abcdef1"
]


#--------------------------------------------------EKS Cluster Variables-------------------------------------------------#

cluster_name = "test-eks-cluster"

cluster_version = "1.33"


#--------------------------------------------------EKS Managed Node Group Variables-------------------------------------------------#

node_group_name = "test-eks-ng"

node_group_instance_types = [
  "t3.medium"
]

node_group_capacity_type = "ON_DEMAND"

node_group_min_size = 1

node_group_desired_size = 2

node_group_max_size = 3

node_group_disk_size = 50

node_group_ami_type = "AL2023_x86_64_STANDARD"
```

Replace the example VPC and subnet IDs with actual AWS resources.

---

# Terraform Commands

## Initialize

```bash
terraform init
```

## Format

```bash
terraform fmt -recursive
```

## Validate

```bash
terraform validate
```

## Plan

```bash
terraform plan -var-file="test.tfvars"
```

## Apply

```bash
terraform apply -var-file="test.tfvars"
```

## Destroy

```bash
terraform destroy -var-file="test.tfvars"
```

---

# Input Validation

The module contains Terraform-native validation for important inputs.

### Application

```text
Maximum 7 characters
```

### Application Code

```text
Maximum 3 characters
```

### Environment

```text
Dev
Qa
Stage
PreProd
Production
```

### Environment Code

```text
Exactly 2 characters
```

### Owner

Must be a valid:

```text
@veen.com
```

email address.

### Application Owner

Must be a valid:

```text
@veen.com
```

email address.

### Backup

Allowed:

```text
N/A
NonProd
Prod
```

### Cluster Version

Expected format:

```text
MAJOR.MINOR
```

### VPC ID

Expected format:

```text
vpc-xxxxxxxxxxxxxxxxx
```

### Subnet IDs

Requirements:

```text
Minimum 2 subnet IDs
Valid AWS subnet IDs
No duplicate subnet IDs
```

### Node Group

The module validates:

```text
Instance types must not be empty
Capacity type must be ON_DEMAND or SPOT
Minimum size >= 0
Desired size >= 1
Maximum size >= 1
Disk size >= 20 GiB
AMI type must be supported
```

---

# Recommended Node Group Configuration

For a development/test environment:

```hcl
node_group_instance_types = [
  "t3.medium"
]

node_group_capacity_type = "ON_DEMAND"

node_group_min_size     = 1
node_group_desired_size = 2
node_group_max_size     = 3

node_group_disk_size = 50

node_group_ami_type = "AL2023_x86_64_STANDARD"
```

For production, select instance types and scaling limits based on workload requirements, CPU/memory utilization, availability requirements, and cost objectives.

---

# Subnet Requirements

EKS requires the cluster to be associated with appropriate subnets across Availability Zones.

This module requires:

```text
Minimum: 2 subnets
```

Recommended configuration:

```text
Availability Zone A
    └── Subnet A

Availability Zone B
    └── Subnet B

Availability Zone C
    └── Subnet C
```

For production environments, using subnets across multiple Availability Zones is recommended for improved availability.

---

# VPC Selection

The module supports existing VPC selection.

## Using VPC ID

```hcl
vpc_id = "vpc-0123456789abcdef0"
```

## Using VPC Name

```hcl
vpc_name = "TF_VPC"
```

The module should resolve the appropriate existing VPC based on the configured selection method.

---

# Example Project Structure

A recommended root-module structure:

```text
terraform-eks/
│
├── main.tf
├── variables.tf
├── outputs.tf
├── providers.tf
├── versions.tf
├── locals.tf
│
├── test.tfvars
│
└── README.md
```

If this repository itself is the reusable module:

```text
aws-eks-module/
│
├── main.tf
├── variables.tf
├── outputs.tf
├── locals.tf
├── data.tf
├── versions.tf
├── README.md
│
└── examples/
    └── basic/
        ├── main.tf
        ├── variables.tf
        ├── outputs.tf
        └── terraform.tfvars
```

---

# Security Considerations

This module follows an existing-infrastructure approach and does not create a new VPC.

Before deploying the module, ensure that:

* IAM permissions follow least privilege
* EKS control-plane access is appropriately restricted
* Worker nodes are deployed into appropriate subnets
* Security groups are appropriately configured
* EBS volumes are encrypted
* Cluster logging requirements are evaluated
* Kubernetes access is controlled using appropriate IAM/RBAC configuration
* Production workloads use multiple Availability Zones
* Sensitive values are not stored in `.tfvars` files committed to Git

Do not commit credentials, secrets, or sensitive configuration to source control.

---

# Validation and Testing

Run the following before creating infrastructure:

```bash
terraform fmt -check -recursive
terraform init
terraform validate
terraform plan -var-file="test.tfvars"
```

Recommended CI/CD checks include:

```text
Terraform Format
Terraform Validate
Terraform Plan
Security Scanning
Terraform Configuration Scanning
```

Tools such as Checkov can be incorporated into the CI/CD pipeline for infrastructure security scanning.

---

# Troubleshooting

## Error: At least two valid subnet IDs must be provided

Ensure that at least two valid subnet IDs are configured:

```hcl
subnet_ids = [
  "subnet-xxxxxxxxxxxxxxxxx",
  "subnet-yyyyyyyyyyyyyyyyy"
]
```

---

## Error: Duplicate subnet IDs

Do not provide the same subnet more than once.

Invalid:

```hcl
subnet_ids = [
  "subnet-xxxxxxxxxxxxxxxxx",
  "subnet-xxxxxxxxxxxxxxxxx"
]
```

Valid:

```hcl
subnet_ids = [
  "subnet-xxxxxxxxxxxxxxxxx",
  "subnet-yyyyyyyyyyyyyyyyy"
]
```

---

## Error: Invalid cluster version

Use the expected `MAJOR.MINOR` format.

Valid:

```hcl
cluster_version = "1.33"
```

Invalid:

```hcl
cluster_version = "1.33.0"
```

---

## Error: Invalid capacity type

Only the following values are supported:

```text
ON_DEMAND
SPOT
```

Example:

```hcl
node_group_capacity_type = "ON_DEMAND"
```

---

# Design Principles

This module follows several design principles:

### Reusable

The module is intended to be consumed by multiple environments rather than being tightly coupled to a single EKS cluster.

### Validated Inputs

Invalid values should be rejected as early as possible through Terraform variable validation.

### Existing Networking

The module consumes an existing VPC and subnet infrastructure rather than creating networking resources.

### Minimal Scope

The module focuses on:

```text
EKS Cluster
IAM Role
Managed Node Group
```

Additional infrastructure can be managed independently.

### Environment Agnostic

The same module can be used for:

```text
Dev
Qa
Stage
PreProd
Production
```

by changing input variables.

---

# Versioning

Use Git tags to publish stable versions of the module.

Example:

```text
v0.1.0
v0.2.0
v1.0.0
```

Consumers can pin a specific version:

```hcl
module "eks" {
  source = "git::https://github.com/CHERUKURIPRAVEEN/aws-eks-module.git?ref=v1.0.0"

  # ...
}
```

Version pinning is recommended for production workloads.

---

# Example

A complete minimal configuration:

```hcl
module "eks" {
  source = "./"

  application      = "EKSAPP"
  application_code = "EKS"

  environment      = "Dev"
  environment_code = "A1"

  project     = "EKS"
  owner       = "devops@veen.com"
  app_owner   = "appowner@veen.com"
  backup      = "NonProd"
  description = "EKS cluster test environment"

  vpc_id = "vpc-0123456789abcdef0"

  subnet_ids = [
    "subnet-0123456789abcdef0",
    "subnet-0123456789abcdef1"
  ]

  cluster_name    = "test-eks-cluster"
  cluster_version = "1.33"

  node_group_name = "test-eks-ng"

  node_group_instance_types = [
    "t3.medium"
  ]

  node_group_capacity_type = "ON_DEMAND"

  node_group_min_size     = 1
  node_group_desired_size = 2
  node_group_max_size     = 3

  node_group_disk_size = 50

  node_group_ami_type = "AL2023_x86_64_STANDARD"
}
```

---

# License

This project is licensed under the terms specified in the repository's `LICENSE` file.

---

# Author

**Praveen Cherukuri**

DevOps Engineer

---

## Disclaimer

This Terraform module is intended to provide a reusable baseline for deploying Amazon EKS infrastructure. Production deployments should be reviewed against the organization's security, networking, compliance, availability, and operational requirements.

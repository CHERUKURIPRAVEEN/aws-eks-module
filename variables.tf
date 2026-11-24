#--------------------------------------------------COMMON Variables-------------------------------------------------#
variable "application" {
  description = "Application tag value for the EKS Cluster. Maximum of 7 characters."
  type        = string

  validation {
    condition     = length(var.application) <= 7
    error_message = "application value should be maximum of 7 characters"
  }
}

variable "application_code" {
  description = "Application code for the EKS Cluster. Maximum of 3 characters."
  type        = string

  validation {
    condition     = length(var.application_code) <= 3
    error_message = "application code should be maximum of 3 characters"
  }
}

variable "environment" {
  description = "Environment of the EKS Cluster. Possible values: 'Dev','Qa','Stage','PreProd','Production'"
  type        = string
  default     = "Dev"

  validation {
    condition     = contains(["Dev", "Qa", "Stage", "PreProd", "Production"], var.environment)
    error_message = "Environment should be 'Dev','Qa','Stage','PreProd','Production'"
  }
}

variable "environment_code" {
  description = "Environment code for the EKS Cluster. Possible values: 'Dev','Qa','Stage','PreProd','Production'"
  type        = string
  default     = "A1"

  validation {
    condition     = length(var.environment_code) == 2
    error_message = "Environment code like 'A1','S1','S2','SX','P1','P2','PX','PR','PD'"
  }
}

variable "tags" {
  description = "default tags"
  type        = map(string)
  default = {
    "env" = "NP"
  }
}

variable "project" {
  description = "Project for which EKS Cluster is being created"
  type        = string
  default     = ""

  validation {
    condition     = length(var.project) <= 7 || var.project == ""
    error_message = "Project value should be maximum of 7 characters or empty"
  }
}

variable "owner" {
  description = "Email address of the EKS Cluster owner."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9._%+-]+@veen\\.com$", var.owner))
    error_message = "Owner email must be a valid @veen.com address."
  }
}

variable "app_owner" {
  description = "Email address of the application owner."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9._%+-]+@veen\\.com$", var.app_owner))
    error_message = "Application owner email must be a valid @veen.com address."
  }
}


variable "backup" {
  description = "Backup to which the EKS Cluster belongs. Possible values: 'N/A', 'NonProd', 'Prod'"
  type        = string
  default     = "N/A"

  validation {
    condition     = contains(["N/A", "NonProd", "Prod"], var.backup)
    error_message = "Backup must be only these values 'N/A', 'NonProd', 'Prod'."
  }
}

variable "description" {
  description = "Description for which EKS Cluster is being created"
  type        = string

  validation {
    condition     = length(var.description) > 9
    error_message = "Description value should be minimum of 10 characters"
  }
}

#--------------------------------------------------VPC and Subnet Selection Variables-------------------------------------------------#
variable "vpc_id" {
  description = "ID of the existing VPC"
  type        = string
  default     = null

  validation {
    condition = var.vpc_id == null ? true : can(
      regex("^vpc-([0-9a-f]{8}|[0-9a-f]{17})$", var.vpc_id)
    )
    error_message = "Please provide a valid VPC ID."
  }
}

variable "vpc_name" {
  description = "Name of the existing VPC"
  type        = string
  default     = null

  validation {
    condition     = var.vpc_name == null ? true : trimspace(var.vpc_name) != ""
    error_message = "VPC name must not be empty."
  }

  validation {
    condition     = (var.vpc_id != null) != (var.vpc_name != null)
    error_message = "Provide exactly one of vpc_id or vpc_name."
  }
}

variable "subnet_ids" {
  description = "List of existing subnet IDs"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for id in var.subnet_ids :
      can(regex("^subnet-([0-9a-f]{8}|[0-9a-f]{17})$", id))
    ])
    error_message = "All subnet IDs must be valid."
  }

  validation {
    condition     = length(var.subnet_ids) == length(distinct(var.subnet_ids))
    error_message = "Duplicate subnet IDs are not allowed."
  }

  validation {
    condition     = length(var.subnet_ids) == 0 || length(var.subnet_ids) >= 2
    error_message = "At least two subnet IDs must be provided."
  }
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
  default     = []
}

variable "private_subnet_names" {
  description = "List of private subnet names"
  type        = list(string)
  default     = []
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs"
  type        = list(string)
  default     = []
}

variable "public_subnet_names" {
  description = "List of public subnet names"
  type        = list(string)
  default     = []
}

# variable "vpc_id" {
#   description = "ID of the existing VPC where the EKS cluster will be created."
#   type        = string

#   validation {
#     condition     = can(regex("^vpc-[0-9a-fA-F]+$", var.vpc_id))
#     error_message = "vpc_id must be a valid AWS VPC ID."
#   }
# }

# variable "subnet_ids" {
#   description = "List of existing subnet IDs to use for the EKS cluster and managed node group."
#   type        = list(string)

#   validation {
#     condition = (
#       length(var.subnet_ids) >= 2 &&
#       alltrue([
#         for subnet_id in var.subnet_ids :
#         can(regex("^subnet-[0-9a-fA-F]+$", subnet_id))
#       ])
#     )

#     error_message = "At least two valid subnet IDs must be provided."
#   }

#   validation {
#     condition = (
#       length(distinct(var.subnet_ids)) == length(var.subnet_ids)
#     )

#     error_message = "subnet_ids must not contain duplicate subnet IDs."
#   }
# }

#--------------------------------------------------EKS Cluster Variables-------------------------------------------------#
variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster."
  type        = string
  nullable    = false

  validation {
    condition = (
      var.cluster_version == null ||
      can(regex("^[0-9]+\\.[0-9]+$", var.cluster_version))
    )

    error_message = "cluster_version must be in the format MAJOR.MINOR, for example 1.33."
  }
}

variable "cluster_number" {
  description = "Numeric identifier for the EKS cluster. Used to distinguish multiple clusters in the same environment."
  type        = number
  default     = 1

  validation {
    condition     = var.cluster_number >= 1 && var.cluster_number <= 99
    error_message = "cluster_number must be between 1 and 99."
  }
}

variable "endpoint_private_access" {
  description = "Enable private access to the EKS API endpoint"
  type        = bool
  default     = true
}

variable "endpoint_public_access" {
  description = "Enable public access to the EKS API endpoint"
  type        = bool
  default     = false
}

variable "public_access_cidrs" {
  description = "Allowed CIDR blocks for the public EKS API endpoint"
  type        = list(string)
  default     = []
}

#--------------------------------------------------EKS Managed Node Group Variables-------------------------------------------------#
variable "create_default_node_group" {
  description = "Whether to create the default EKS managed node group."
  type        = bool
  default     = true
}

variable "node_group_name" {
  description = "Name of the EKS managed node group."
  type        = string
  default     = null

  validation {
    condition = (
      var.node_group_name == null ||
      length(trimspace(var.node_group_name)) > 0
    )
    error_message = "If provided, node_group_name must not be empty."
  }
}

variable "node_group_instance_types" {
  description = "EC2 instance types for the EKS managed node group."
  type        = list(string)
  default     = ["t3.medium"]

  validation {
    condition     = length(var.node_group_instance_types) > 0
    error_message = "At least one node group instance type must be provided."
  }
}

variable "node_group_capacity_type" {
  description = "Capacity type for the EKS managed node group."
  type        = string
  default     = "ON_DEMAND"

  validation {
    condition = contains(
      ["ON_DEMAND", "SPOT"],
      var.node_group_capacity_type
    )
    error_message = "node_group_capacity_type must be either ON_DEMAND or SPOT."
  }
}

variable "node_group_min_size" {
  description = "Minimum number of nodes in the managed node group."
  type        = number
  default     = 1

  validation {
    condition     = var.node_group_min_size >= 0
    error_message = "node_group_min_size must be greater than or equal to 0."
  }
}

variable "node_group_desired_size" {
  description = "Desired number of nodes in the managed node group."
  type        = number
  default     = 2

  validation {
    condition     = var.node_group_desired_size >= 1
    error_message = "node_group_desired_size must be at least 1."
  }
}

variable "node_group_max_size" {
  description = "Maximum number of nodes in the managed node group."
  type        = number
  default     = 3

  validation {
    condition     = var.node_group_max_size >= 1
    error_message = "node_group_max_size must be at least 1."
  }
}

variable "node_group_disk_size" {
  description = "Root EBS volume size in GiB for worker nodes."
  type        = number
  default     = 50

  validation {
    condition     = var.node_group_disk_size >= 20
    error_message = "node_group_disk_size must be at least 20 GiB."
  }
}

variable "node_group_ami_type" {
  description = "AMI type for the managed node group."
  type        = string
  default     = "AL2023_x86_64_STANDARD"

  validation {
    condition = contains(
      [
        "AL2023_x86_64_STANDARD",
        "AL2023_ARM_64_STANDARD",
        "AL2023_x86_64_NVIDIA",
        "AL2023_x86_64_NEURON"
      ],
      var.node_group_ami_type
    )

    error_message = "Unsupported node_group_ami_type."
  }
}

#--------------------------------------------------EKS KMS Encryption Variables-------------------------------------------------#
variable "enable_cluster_kms_encryption" {
  description = "Enable customer-managed KMS encryption for EKS secrets."
  type        = bool
  default     = false
  nullable    = false
}

variable "cluster_kms_key_arn" {
  description = "ARN of an existing customer-managed KMS key."
  type        = string
  default     = null

  validation {
    condition = (
      !var.enable_cluster_kms_encryption ||
      try(trimspace(var.cluster_kms_key_arn) != "", false)
    )
    error_message = "A KMS key ARN is required when customer-managed encryption is enabled."
  }
}

#--------------------------------------------------EKS CNI Policy Attachment Variable-------------------------------------------------#
variable "attach_cni_policy" {
  description = "Attach the Amazon EKS CNI policy to the worker node IAM role."
  type        = bool
  default     = true
  nullable    = false
}

#--------------------------------------------------EKS Node Group Launch Template Variables-------------------------------------------------#
variable "enable_launch_template" {
  description = "Enable custom EC2 launch template for the default node group."
  type        = bool
  default     = true
}

variable "node_group_volume_type" {
  description = "Root EBS volume type."
  type        = string
  default     = "gp3"

  validation {
    condition     = contains(["gp2", "gp3"], var.node_group_volume_type)
    error_message = "Volume type must be gp2 or gp3."
  }
}

variable "node_group_volume_kms_key_arn" {
  description = "Optional customer-managed KMS key ARN for worker EBS encryption."
  type        = string
  default     = null
}

variable "enable_node_detailed_monitoring" {
  description = "Enable detailed EC2 CloudWatch monitoring."
  type        = bool
  default     = false
}

#--------------------------------------------------EKS Cluster Admin Role Variable-------------------------------------------------#
# variable "cluster_admin_role_arn" {
#   description = "Existing IAM role ARN granted EKS cluster administrator access."
#   type        = string
#   nullable    = false

#   validation {
#     condition = can(regex(
#       "^arn:aws[a-zA-Z-]*:iam::[0-9]{12}:role/.+$",
#       var.cluster_admin_role_arn
#     ))
#     error_message = "Provide a valid IAM role ARN."
#   }
# }

variable "access_entries" {
  description = "Additional IAM roles and their EKS access policies."
  type = map(object({
    principal_arn = string
    policy        = string
    scope         = string
    namespaces    = optional(list(string), [])
  }))

  default = {}

  validation {
    condition = alltrue([
      for entry in values(var.access_entries) :
      can(regex(
        "^arn:aws[a-zA-Z-]*:iam::[0-9]{12}:role/.+$",
        entry.principal_arn
      ))
    ])
    error_message = "Each principal_arn must be a valid IAM role ARN."
  }

  validation {
    condition = alltrue([
      for entry in values(var.access_entries) :
      contains([
        "AmazonEKSClusterAdminPolicy",
        "AmazonEKSAdminPolicy",
        "AmazonEKSEditPolicy",
        "AmazonEKSViewPolicy"
      ], entry.policy)
    ])
    error_message = "Provide a supported EKS access policy."
  }

  validation {
    condition = alltrue([
      for entry in values(var.access_entries) :
      contains(["cluster", "namespace"], entry.scope)
    ])
    error_message = "Scope must be cluster or namespace."
  }

  validation {
    condition = alltrue([
      for entry in values(var.access_entries) :
      entry.scope == "cluster"
      ? length(entry.namespaces) == 0
      : length(entry.namespaces) > 0
    ])
    error_message = "Cluster scope must have no namespaces; namespace scope requires at least one namespace."
  }
}

#--------------------------------------------------EKS VPC CNI Add-on Variables-------------------------------------------------#
variable "enable_vpc_cni_addon" {
  description = "Enable the Amazon EKS managed VPC CNI add-on."
  type        = bool
  default     = true
}

variable "vpc_cni_addon_version" {
  description = "Optional VPC CNI add-on version. Null uses the EKS default compatible version."
  type        = string
  default     = null
}

variable "enable_coredns_addon" {
  description = "Enable the Amazon EKS managed CoreDNS add-on."
  type        = bool
  default     = true
}

variable "coredns_addon_version" {
  description = "Optional CoreDNS add-on version. Null uses an AWS-selected compatible version."
  type        = string
  default     = null
}

variable "enable_kube_proxy_addon" {
  description = "Enable the Amazon EKS managed kube-proxy add-on."
  type        = bool
  default     = true
}

variable "kube_proxy_addon_version" {
  description = "Optional kube-proxy add-on version. Null uses the AWS-selected compatible default."
  type        = string
  default     = null
}

variable "enable_ebs_csi_addon" {
  description = "Enable the Amazon EBS CSI Driver add-on."
  type        = bool
  default     = true
}

variable "ebs_csi_addon_version" {
  description = "Optional EBS CSI Driver version. Null uses the AWS-selected compatible default."
  type        = string
  default     = null
}

variable "pod_identity_agent_version" {
  description = "Optional EKS Pod Identity Agent version. Null uses the AWS-selected compatible default."
  type        = string
  default     = null
}

#--------------------------------------------------EKS Cluster Deletion Protection Variable-------------------------------------------------#
variable "enable_deletion_protection" {
  description = "Protect the EKS cluster from accidental deletion."
  type        = bool
  default     = true
}
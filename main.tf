/*
* AWS EKS Module
* Managed by Praveen Cherukuri
*/
#-------------------------------------------------EKS Module-------------------------------------------------#
locals {
  mandatory_tags = {
    application      = var.application
    application_code = var.application_code
    environment      = var.environment
    environment_code = var.environment_code
    project          = var.project
    backup           = var.backup
    owner            = var.owner
    app_owner        = var.app_owner
    description      = var.description
  }

  common_tags = merge(
    var.tags,
    local.mandatory_tags
  )

  cluster_name      = upper("${var.environment}-${var.environment_code}-${var.application_code}-${var.application}-${format("%02d", var.cluster_number)}")
  cluster_role_name = "${local.cluster_name}-CLUSTER-ROLE"

  node_role_name = "${local.cluster_name}-NODE-ROLE"
  node_group_name = upper(
    coalesce(
      var.node_group_name,
      "${local.cluster_name}-NODES"
    )
  )

  selected_vpc_id = var.vpc_id != null ? var.vpc_id : data.aws_vpc.selected[0].id
  selected_private_subnet_ids = length(var.private_subnet_ids) > 0 ? var.private_subnet_ids : [
    for subnet in data.aws_subnet.private : subnet.id
  ]
  selected_public_subnet_ids = length(var.public_subnet_ids) > 0 ? var.public_subnet_ids : [
    for subnet in data.aws_subnet.public : subnet.id
  ]
  selected_subnet_ids = length(var.subnet_ids) > 0 ? var.subnet_ids : concat(
    local.selected_private_subnet_ids,
    local.selected_public_subnet_ids
  )
}

data "aws_vpc" "selected" {
  count = var.vpc_id == null ? 1 : 0

  filter {
    name   = "tag:Name"
    values = [var.vpc_name]
  }
}

data "aws_subnet" "private" {
  for_each = length(var.subnet_ids) == 0 ? toset(var.private_subnet_names) : toset([])

  vpc_id = local.selected_vpc_id

  filter {
    name   = "tag:Name"
    values = [each.value]
  }
}

data "aws_subnet" "public" {
  for_each = length(var.subnet_ids) == 0 ? toset(var.public_subnet_names) : toset([])

  vpc_id = local.selected_vpc_id

  filter {
    name   = "tag:Name"
    values = [each.value]
  }
}

data "aws_subnet" "selected" {
  for_each = toset(local.selected_subnet_ids)

  id = each.value
}

resource "aws_iam_role" "cluster" {
  name = local.cluster_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "eks.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = local.cluster_role_name
    }
  )
}

resource "aws_cloudwatch_log_group" "cluster" {
  count = var.enable_cluster_logging && length(var.enabled_cluster_log_types) > 0 ? 1 : 0

  name              = "/aws/eks/${local.cluster_name}/cluster"
  retention_in_days = var.cluster_log_retention_days

  tags = merge(
    local.common_tags,
    {
      Name = "${local.cluster_name}-LOGS"
    }
  )
}

resource "aws_eks_cluster" "this" {
  name                      = local.cluster_name
  role_arn                  = aws_iam_role.cluster.arn
  version                   = var.cluster_version
  enabled_cluster_log_types = var.enable_cluster_logging ? var.enabled_cluster_log_types : []

  vpc_config {
    subnet_ids              = local.selected_subnet_ids
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.endpoint_public_access ? var.public_access_cidrs : null
  }

  dynamic "encryption_config" {
    for_each = var.enable_cluster_kms_encryption ? [1] : []

    content {
      provider {
        key_arn = var.cluster_kms_key_arn
      }

      resources = ["secrets"]
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster,
    aws_cloudwatch_log_group.cluster
  ]

  tags = merge(
    local.common_tags,
    {
      Name = local.cluster_name
    }
  )
}

resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

#----------------------------------------------------------------Node Group-------------------------------------------------#
resource "aws_iam_role" "node_group" {
  name = local.node_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = local.node_role_name
    }
  )
}

resource "aws_iam_role_policy_attachment" "node_group_cni" {
  count = var.attach_cni_policy ? 1 : 0

  role       = aws_iam_role.node_group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "node_group_worker" {
  role       = aws_iam_role.node_group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_group_ecr" {
  role       = aws_iam_role.node_group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
}

check "node_group_scaling" {
  assert {
    condition = (
      var.node_group_min_size <= var.node_group_desired_size &&
      var.node_group_desired_size <= var.node_group_max_size
    )

    error_message = "Node group scaling must satisfy min_size <= desired_size <= max_size."
  }
}

resource "aws_eks_node_group" "this" {
  cluster_name = aws_eks_cluster.this.name

  node_group_name = local.node_group_name
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = local.selected_subnet_ids
  instance_types  = var.node_group_instance_types
  capacity_type   = var.node_group_capacity_type
  ami_type        = var.node_group_ami_type
  disk_size       = var.node_group_disk_size

  scaling_config {
    min_size     = var.node_group_min_size
    desired_size = var.node_group_desired_size
    max_size     = var.node_group_max_size
  }

  update_config {
    max_unavailable = 1
  }

  tags = merge(
    local.common_tags,
    {
      Name = local.node_group_name
    }
  )
}

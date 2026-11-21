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

  create_launch_template = var.create_default_node_group && var.enable_launch_template
  launch_template_name   = "${local.node_group_name}-LT"
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

resource "aws_eks_cluster" "this" {
  name     = local.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.cluster_version

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
    aws_iam_role_policy_attachment.cluster
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
  name  = local.node_role_name
  count = var.create_default_node_group ? 1 : 0

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
  count = var.create_default_node_group && var.attach_cni_policy ? 1 : 0

  role       = aws_iam_role.node_group[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "node_group_worker" {
  count = var.create_default_node_group ? 1 : 0

  role       = aws_iam_role.node_group[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_group_ecr" {
  count = var.create_default_node_group ? 1 : 0

  role       = aws_iam_role.node_group[0].name
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
  count        = var.create_default_node_group ? 1 : 0

  node_group_name = local.node_group_name
  node_role_arn   = aws_iam_role.node_group[0].arn
  subnet_ids      = local.selected_subnet_ids
  instance_types  = var.node_group_instance_types
  capacity_type   = var.node_group_capacity_type
  ami_type        = var.node_group_ami_type
  disk_size       = local.create_launch_template ? null : var.node_group_disk_size

  dynamic "launch_template" {
    for_each = aws_launch_template.node_group

    content {
      id      = launch_template.value.id
      version = tostring(launch_template.value.latest_version)
    }
  }

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

#----------------------------------------------------------------Launch Template-------------------------------------------------#
resource "aws_launch_template" "node_group" {
  count = local.create_launch_template ? 1 : 0

  name                   = local.launch_template_name
  description            = "Launch template for ${local.node_group_name}"
  update_default_version = true

  # Enforce IMDSv2
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "disabled"
  }

  # Root EBS volume
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.node_group_disk_size
      volume_type           = var.node_group_volume_type
      encrypted             = true
      kms_key_id            = var.node_group_volume_kms_key_arn
      delete_on_termination = true
    }
  }

  # EC2 monitoring
  monitoring {
    enabled = var.enable_node_detailed_monitoring
  }

  # EC2 instance tags
  tag_specifications {
    resource_type = "instance"

    tags = merge(
      local.common_tags,
      {
        Name = local.node_group_name
      }
    )
  }

  # EBS volume tags
  tag_specifications {
    resource_type = "volume"

    tags = merge(
      local.common_tags,
      {
        Name = "${local.node_group_name}-EBS"
      }
    )
  }

  # Launch template tags
  tags = merge(
    local.common_tags,
    {
      Name = local.launch_template_name
    }
  )
}

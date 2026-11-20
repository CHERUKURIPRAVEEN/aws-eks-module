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

  cluster_name = upper(
    "${var.environment}-${var.environment_code}-${var.application_code}-${var.application}-${format("%02d", var.cluster_number)}"
  )

  selected_vpc_id     = data.aws_vpc.selected.id
  selected_subnet_ids = var.subnet_ids

  selected_subnet_azs = [
    for subnet in data.aws_subnet.selected :
    subnet.availability_zone
  ]
}

data "aws_vpc" "selected" {
  id = var.vpc_id
}

data "aws_subnet" "selected" {
  for_each = toset(local.selected_subnet_ids)

  id = each.value
}

check "subnets_belong_to_vpc" {
  assert {
    condition = alltrue([
      for subnet_id in local.selected_subnet_ids :
      data.aws_subnet.selected[subnet_id].vpc_id == local.selected_vpc_id
    ])

    error_message = "All subnet_ids must belong to the specified vpc_id."
  }
}

check "subnets_in_multiple_azs" {
  assert {
    condition = length(
      distinct(local.selected_subnet_azs)
    ) >= 2

    error_message = "At least two subnets in different Availability Zones must be provided."
  }
}

resource "aws_iam_role" "cluster" {
  name = "${local.cluster_name}-cluster-role"

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

  tags = {
    Name = "${local.cluster_name}-cluster-role"
  }
}

resource "aws_eks_cluster" "this" {
  name     = local.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids = local.selected_subnet_ids
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster
  ]

  tags = merge(
    local.mandatory_tags,
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
  name = coalesce(
    var.node_group_name,
    "${local.cluster_name}-node-role"
  )

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

  tags = {
    Name = coalesce(
      var.node_group_name,
      "${local.cluster_name}-node-role"
    )
  }
}

resource "aws_iam_role_policy_attachment" "node_group_worker" {
  role       = aws_iam_role.node_group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_group_ecr" {
  role       = aws_iam_role.node_group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
}

resource "aws_iam_role_policy_attachment" "node_group_cni" {
  role       = aws_iam_role.node_group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
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

  node_group_name = coalesce(
    var.node_group_name,
    "${local.cluster_name}-nodes"
  )

  node_role_arn = aws_iam_role.node_group.arn

  subnet_ids = local.selected_subnet_ids

  instance_types = var.node_group_instance_types
  capacity_type  = var.node_group_capacity_type
  ami_type       = var.node_group_ami_type
  disk_size      = var.node_group_disk_size

  scaling_config {
    min_size     = var.node_group_min_size
    desired_size = var.node_group_desired_size
    max_size     = var.node_group_max_size
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_group_worker,
    aws_iam_role_policy_attachment.node_group_ecr,
    aws_iam_role_policy_attachment.node_group_cni
  ]

  tags = merge(
    local.mandatory_tags,
    {
      Name = coalesce(
        var.node_group_name,
        "${local.cluster_name}-nodes"
      )
    }
  )
}

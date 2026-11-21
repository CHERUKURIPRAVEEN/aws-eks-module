#-------------------------------------------------Common Variables-------------------------------------------------#
application      = "Atf"
application_code = "TF"
environment      = "Dev"
project          = "Ptf"
backup           = "NonProd"
owner            = "praveen.cherukuri@veen.com"
app_owner        = "praveen.cherukuri@veen.com"
description      = "This is a test EKS cluster created by Terraform module"
environment_code = "A1"

tags = {
  managed_by  = "Terraform"
  cost_center = "CloudOps"
}

#--------------------------------------------------EKS cluster-------------------------------------------------------#
cluster_number = 1

#--------------------------------------------------VPC configuration-------------------------------------------------#
vpc_name = "MANAGEMENT_VPC"

#--------------------------------------------------Subnet configuration----------------------------------------------#
subnet_ids = ["subnet-0bf5dc9a8c4108beb", "subnet-0c1750b560afca202"]

#--------------------------------------------------Endpoint security-------------------------------------------------#
endpoint_private_access = true
endpoint_public_access  = false
public_access_cidrs     = []

#--------------------------------------------------Managed node group-----------------------------------------------#
create_default_node_group = true
node_group_instance_types = ["t3.medium"]
node_group_capacity_type  = "ON_DEMAND"
node_group_min_size       = 1
node_group_desired_size   = 2
node_group_max_size       = 3
node_group_disk_size      = 50
node_group_ami_type       = "AL2023_x86_64_STANDARD"

enable_launch_template = true
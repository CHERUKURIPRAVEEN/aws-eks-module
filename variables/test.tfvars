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
cluster_number  = 1
cluster_version = "1.35"

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

#--------------------------------------------------Cluster admin role ARN-------------------------------------------#
# cluster_admin_role_arn = "arn:aws:iam::123456789012:role/YourExistingAdminRole"

#--------------------------------------------------Access entries-----------------------------------------------------#
access_entries = {}
# access_entries = {
#   developers = {
#     principal_arn = "arn:aws:iam::123456789012:role/ExampleDeveloperRole"
#     policy        = "AmazonEKSEditPolicy"
#     scope         = "namespace"
#     namespaces    = ["development"]
#   }

#   readonly = {
#     principal_arn = "arn:aws:iam::123456789012:role/ExampleReadOnlyRole"
#     policy        = "AmazonEKSViewPolicy"
#     scope         = "cluster"
#     namespaces    = []
#   }
# }

#--------------------------------------------------EKS VPC CNI Add-on Variables-------------------------------------------------#
enable_vpc_cni_addon    = true
enable_coredns_addon    = true
enable_kube_proxy_addon = true
enable_ebs_csi_addon    = true

# Leave null to use the AWS-selected compatible default.
vpc_cni_addon_version      = null
coredns_addon_version      = null
kube_proxy_addon_version   = null
ebs_csi_addon_version      = null
pod_identity_agent_version = null

#--------------------------------------------------EKS Cluster Deletion Protection-------------------------------------------#
enable_deletion_protection = false
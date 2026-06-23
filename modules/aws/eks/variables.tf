variable "deployment_name" {
  description = "Deployment name, also used as prefix for resources"
  type        = string
}

variable "machine_type" {
  description = "AWS EC2 instance type"
  type        = string
}

variable "machine_image" {
  description = "AWS EKS machine image"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "cluster_size" {}

variable "disk_size" {}

variable "cluster_version" {
  description = "EKS Cluster version"
  type        = string
}

variable "subnets_cidrs" {
  description = "CIDR blocks for the subnets in each zone"
  type        = map
}

variable "resource_tags" {
  description = "hash with tags for all resources"
}

# When the caller lacks iam:CreateRole (typical for non-admin SSO roles), set
# shared_iam_role_name to an existing role that trusts both eks.amazonaws.com
# and ec2.amazonaws.com and has the EKS cluster + worker + CNI + ECR-read
# policies attached. The module will then skip creating new roles and pass the
# shared role as both the cluster role and the node-group role.
variable "shared_iam_role_name" {
  description = "Name of an existing IAM role to reuse for both the EKS cluster role and the node-group role. Leave empty to create per-deployment roles (requires iam:CreateRole)."
  type        = string
  default     = ""
}
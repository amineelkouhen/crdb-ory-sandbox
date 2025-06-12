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
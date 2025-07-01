variable "name" {
  description = "Project name, also used as prefix for resources"
  type        = string
}

variable "resource_tags" {
  description = "hash with tags for all resources"
}

variable "availability_zone" {
  description = "Default availability zone"
  type        = string
}

variable "subnet" {
  description = "Id of the subnet, to which this bastion belongs"
  type        = string
}

variable "security_groups" {
  description = "List of security groups to attached to the bastion"
  type        = list(string)
}

variable "machine_image" {
  description = "AWS EC2 machine image"
  type        = string
}

variable "machine_type" {
  description = "AWS EC2 instance type"
  type        = string
}

variable "ssh_key_name" {
  description = "AWS EC2 Keypair's name"
  type        = string
}

variable "ssh_user" {
  description = "SSH linux user"
  type        = string
}

variable "ssh_public_key" {
  description = "Path to SSH public key"
  type        = string
}

variable "ssh_private_key" {
  description = "Path to SSH private key"
  type        = string
}

variable "cluster_fqdn" {
  description = "CRDB Cluster fqdn"
  type        = string
}

variable "cockroach_release" {
  description = "CRDB Release"
  type        = string
}

variable "regions" {}

variable "cluster_organization" {
  description = "Cluster Organization"
  type        = string
}

variable "cluster_license" {
  description = "Cluster License"
  type        = string
}

variable "hydra_image" {
  description = "Repository image for Ory Hydra"
  type        = string
}

variable "hydra_release" {
  description = "Release tag for Ory Hydra"
  type        = string
}

variable "hydra_admin_port" {
  description = "Admin port for Ory Hydra"
  type        = number
}

variable "hydra_public_port" {
  description = "Public port for Ory Hydra"
  type        = number
}

variable "kratos_image" {
  description = "Repository image for Ory Kratos"
  type        = string
}

variable "kratos_release" {
  description = "Release tag for Ory Kratos"
  type        = string
}

variable "kratos_admin_port" {
  description = "Admin port for Ory Kratos"
  type        = number
}

variable "kratos_public_port" {
  description = "Public port for Ory Kratos"
  type        = number
}

variable "keto_image" {
  description = "Repository image for Ory Keto"
  type        = string
}

variable "keto_release" {
  description = "Release tag for Ory Keto"
  type        = string
}

variable "keto_read_port" {
  description = "Read port for Ory Keto"
  type        = number
}

variable "keto_write_port" {
  description = "Write port for Ory Keto"
  type        = number
}

variable "k8s_cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "simulator_repository" {
  description = "workload simulator repository"
  type        = string
}

variable "dependencies" {
  type        = list
}

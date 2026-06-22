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
  type = list(any)
}

############################################################
# Multi-region behavior (all defaults preserve single-region)
############################################################

variable "init_schema" {
  description = "If true, this bastion runs DROP/CREATE for the hydra/kratos/keto databases. The single-region default is true. Set to false for the deploy-only bastion in a multi-region topology so it does not race with the initializer."
  type        = bool
  default     = true
}

variable "multi_region" {
  description = "If true, this bastion is part of a multi-region deployment. Enables Istio multi-primary install and multi-region URL/secret templating in the Helm values files."
  type        = bool
  default     = false
}

variable "peer_init_marker_table" {
  description = "Fully qualified table name (e.g. hydra.hydra_client) the deploy-only bastion polls before running helm install. Only used when init_schema = false."
  type        = string
  default     = ""
}

variable "crdb_multi_region_sql" {
  description = "Multi-line SQL applied by the initializer bastion after schema creation to configure CRDB locality (ALTER DATABASE ... PRIMARY REGION / ADD REGION / SURVIVE / per-table REGIONAL BY ROW or GLOBAL). Empty for single-region."
  type        = string
  default     = ""
}

variable "hydra_issuer_url" {
  description = "Global public URL for Hydra (used as urls.self.issuer in the Helm values). Empty leaves the values file unchanged."
  type        = string
  default     = ""
}

variable "kratos_public_base_url" {
  description = "Global public URL for Kratos (used as serve.public.base_url in the Helm values). Empty leaves the values file unchanged."
  type        = string
  default     = ""
}

variable "hydra_system_secret" {
  description = "Shared hydra.secrets.system value. Must be identical across all regions for cross-region token decryption. Empty leaves the values file unchanged."
  type        = string
  default     = ""
  sensitive   = true
}

variable "kratos_default_secret" {
  description = "Shared kratos.secrets.default value. Must be identical across all regions. Empty leaves the values file unchanged."
  type        = string
  default     = ""
  sensitive   = true
}

variable "kratos_cookie_secret" {
  description = "Shared kratos.secrets.cookie value. Must be identical across all regions. Empty leaves the values file unchanged."
  type        = string
  default     = ""
  sensitive   = true
}

variable "istio_root_ca_cert" {
  description = "PEM-encoded root CA certificate used to bootstrap Istio multi-primary identity. Must be identical across all regions. Only consumed when multi_region = true."
  type        = string
  default     = ""
  sensitive   = true
}

variable "istio_root_ca_key" {
  description = "PEM-encoded root CA private key for Istio multi-primary identity. Must match istio_root_ca_cert and be identical across all regions. Only consumed when multi_region = true."
  type        = string
  default     = ""
  sensitive   = true
}

variable "istio_cluster_name" {
  description = "Logical Istio cluster name for this region (e.g. mumbai). Used by istioctl install --set values.global.multiCluster.clusterName."
  type        = string
  default     = ""
}

variable "istio_network_name" {
  description = "Logical Istio network name for this region (e.g. mumbai-net). Used by istioctl install --set values.global.network."
  type        = string
  default     = ""
}

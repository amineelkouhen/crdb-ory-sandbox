variable "deployment_name" {
  description = "Deployment Name (used as resource prefix and DNS subdomain root)"
}

variable "aws_access_key" {
  description = "AWS Access Key"
}

variable "aws_secret_key" {
  description = "AWS Secret Key"
}

variable "aws_session_token" {
  description = "AWS Session Token"
}

variable "env" {
  default = "mr"
}

variable "hosted_zone" {
  description = "Public Route 53 hosted zone in which latency-based records are created."
  default     = "sko-iam-demo.com"
}

############################################################
# Regions (Mumbai + Hyderabad)
############################################################

variable "regions" {
  default = ["ap-south-1", "ap-south-2"]
}

variable "istio_cluster_names" {
  description = "Logical Istio cluster name per region, used for mesh identity."
  default     = ["mumbai", "hyderabad"]
}

variable "istio_network_names" {
  description = "Logical Istio network name per region (multi-network topology)."
  default     = ["mumbai-net", "hyderabad-net"]
}

############################################################
# CRDB networking + sizing (per region, list-indexed)
############################################################

variable "crdb_vpc_cidr" {
  default = ["10.1.0.0/16", "10.2.0.0/16"]
}

variable "crdb_subnets" {
  default = [
    {
      ap-south-1a = "10.1.1.0/24"
      ap-south-1b = "10.1.2.0/24"
      ap-south-1c = "10.1.3.0/24"
    },
    {
      ap-south-2a = "10.2.1.0/24"
      ap-south-2b = "10.2.2.0/24"
      ap-south-2c = "10.2.3.0/24"
    }
  ]
}

variable "crdb_cluster_size" {
  default = [3, 3]
}

variable "crdb_machine_images" {
  # Ubuntu 24.04 LTS per region (set during apply if region defaults differ)
  default = ["ami-04b70fa74e45c3917", "ami-04b70fa74e45c3917"]
}

variable "crdb_machine_type" {
  default = "m5.xlarge"
}

variable "crdb_volume_size" {
  default = 200
}

variable "crdb_volume_type" {
  default = "gp3"
}

variable "crdb_release" {
  default = "https://binaries.cockroachdb.com/cockroach-v24.3.8.linux-amd64.tgz"
}

############################################################
# EKS networking + sizing (per region, list-indexed)
############################################################

variable "eks_vpc_cidr" {
  default = ["10.11.0.0/16", "10.12.0.0/16"]
}

variable "eks_public_subnets" {
  default = [
    {
      ap-south-1a = "10.11.1.0/24"
      ap-south-1b = "10.11.2.0/24"
      ap-south-1c = "10.11.3.0/24"
    },
    {
      ap-south-2a = "10.12.1.0/24"
      ap-south-2b = "10.12.2.0/24"
      ap-south-2c = "10.12.3.0/24"
    }
  ]
}

variable "eks_version" {
  default = "1.33"
}

variable "eks_machine_type" {
  default = "m5.large"
}

variable "eks_machine_image" {
  default = "AL2023_x86_64_STANDARD"
}

variable "eks_cluster_size" {
  default = 3
}

variable "eks_volume_size" {
  default = 60
}

############################################################
# Bastion (client) networking, per region
############################################################

variable "client_vpc_cidr" {
  default = ["172.31.0.0/16", "172.32.0.0/16"]
}

variable "client_subnet" {
  default = [
    { ap-south-1a = "172.31.1.0/24" },
    { ap-south-2a = "172.32.1.0/24" }
  ]
}

variable "client_machine_type" {
  default = "m6a.large"
}

variable "client_machine_image" {
  # Ubuntu 24.04 LTS in ap-south-1 / ap-south-2 (placeholder; override per region if needed)
  default = ["ami-0cf2b4e024cdb6960", "ami-0cf2b4e024cdb6960"]
}

############################################################
# SSH
############################################################

variable "ssh_public_key" {
  default = "~/.ssh/id_rsa.pub"
}

variable "ssh_private_key" {
  default = "~/.ssh/id_rsa"
}

variable "ssh_user" {
  default = "ubuntu"
}

############################################################
# Ory Hydra / Kratos / Keto (images, releases, ports)
############################################################

variable "hydra_image" {
  default = "europe-docker.pkg.dev/ory-artifacts/ory-enterprise/hydra-oel"
}

variable "hydra_release_tag" {
  default = "19fae4f763fa139db38db601000cb80b53ebde4d"
}

variable "hydra_admin_port" {
  default = 4445
}

variable "hydra_public_port" {
  default = 4444
}

variable "kratos_image" {
  default = "europe-docker.pkg.dev/ory-artifacts/ory-enterprise-kratos/kratos-oel"
}

variable "kratos_release_tag" {
  default = "19fae4f763fa139db38db601000cb80b53ebde4d"
}

variable "kratos_admin_port" {
  default = 4433
}

variable "kratos_public_port" {
  default = 4434
}

variable "keto_image" {
  default = "oryd/keto"
}

variable "keto_release_tag" {
  default = "v0.14.0"
}

variable "keto_read_port" {
  default = 4466
}

variable "keto_write_port" {
  default = 4467
}

variable "ory_simulator_repository" {
  default = "https://github.com/amineelkouhen/crdb-ory-load-test"
}

############################################################
# CRDB licensing
############################################################

variable "organization_name" {
  default = "ory_sandbox"
}

variable "cluster_license" {
  description = "Cluster License"
}

############################################################
# Multi-region shared secrets (must be identical across regions)
# Supply via tfvars / CLI / env vars; no defaults to avoid leaking
# placeholder values into deployments.
############################################################

variable "hydra_system_secret" {
  description = "Hydra hydra.secrets.system value, shared across regions for cross-region token decryption."
  type        = string
  sensitive   = true
}

variable "kratos_default_secret" {
  description = "Kratos kratos.secrets.default value, shared across regions."
  type        = string
  sensitive   = true
}

variable "kratos_cookie_secret" {
  description = "Kratos kratos.secrets.cookie value, shared across regions."
  type        = string
  sensitive   = true
}

variable "istio_root_ca_cert" {
  description = "PEM-encoded shared Istio root CA certificate."
  type        = string
  sensitive   = true
}

variable "istio_root_ca_key" {
  description = "PEM-encoded shared Istio root CA private key."
  type        = string
  sensitive   = true
}

############################################################
# Multi-region CRDB schema locality
#
# Applied by the initializer (region 1) bastion after schema
# creation. ADD REGION must reference the same logical regions
# the cluster sees in SHOW REGIONS FROM CLUSTER (i.e. AWS region
# names: ap-south-1 / ap-south-2).
############################################################

variable "crdb_multi_region_sql" {
  description = "Multi-line SQL applied by the initializer bastion to set CRDB locality (PRIMARY REGION / ADD REGION / SURVIVE / per-table REGIONAL BY ROW or GLOBAL)."
  type        = string
  default     = <<-EOT
    ALTER DATABASE hydra  PRIMARY REGION "ap-south-1";
    ALTER DATABASE hydra  ADD REGION    "ap-south-2";
    ALTER DATABASE hydra  SURVIVE ZONE FAILURE;

    ALTER DATABASE kratos PRIMARY REGION "ap-south-1";
    ALTER DATABASE kratos ADD REGION    "ap-south-2";
    ALTER DATABASE kratos SURVIVE ZONE FAILURE;

    ALTER DATABASE keto   PRIMARY REGION "ap-south-1";
    ALTER DATABASE keto   ADD REGION    "ap-south-2";
    ALTER DATABASE keto   SURVIVE ZONE FAILURE;
  EOT
}

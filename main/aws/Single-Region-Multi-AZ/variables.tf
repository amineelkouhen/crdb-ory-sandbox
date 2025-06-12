variable "deployment_name" {
  description = "Deployment Name"
  # No default
  # Use CLI or interactive input.
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

variable "regions" {
  default = ["us-east-1"]
}

variable "crdb_vpc_cidr" {
  default = ["10.1.0.0/16"]
}

variable "crdb_subnets" {
  default = [{
    us-east-1a = "10.1.1.0/24"
    us-east-1b = "10.1.2.0/24"
    us-east-1c = "10.1.3.0/24"
  }]
}

variable "eks_vpc_cidr" {
  default = "10.2.0.0/16"
}

variable "eks_version" {
  default = "1.33"
}

variable "eks_public_subnets" {
  default = [{
    us-east-1a = "10.2.1.0/24"
    us-east-1b = "10.2.2.0/24"
    us-east-1c = "10.2.3.0/24"
  }]
}

variable "eks_cluster_size" {
  default = 3
}

variable "eks_machine_type" {
  default = "m5.large"
}

variable "eks_machine_image" {
  // Linux 2023
  default = "AL2023_x86_64_STANDARD"
}

variable "eks_volume_size" {
  default = 60
}

variable "ssh_public_key" {
  default = "~/.ssh/id_rsa.pub"
}

variable "ssh_private_key" {
  default = "~/.ssh/id_rsa"
}

variable "ssh_user" {
  default = "ubuntu"
}

variable "crdb_volume_size" {
  default = 200
}

variable "crdb_volume_type" {
  default = "gp3"
}

// other optional edits *************************************
variable "crdb_cluster_size" {
  # Here we will create a 9-nodes cluster in one region
  default = [3]
}

// other possible edits *************************************
variable "crdb_release" {
  default = "https://binaries.cockroachdb.com/cockroach-v24.3.8.linux-amd64.tgz"
}

variable "crdb_machine_type" {
  default = "m5.large"
}

variable "crdb_machine_images" {
  // Ubuntu 24.04 LTS
  default = ["ami-04b70fa74e45c3917"]
}

variable "env" {
  default = "us"
}

//// Client Configuration

variable "client_vpc_cidr" {
  default = "172.71.0.0/16"
}

variable "client_region" {
  default = "us-west-2"
}

variable "client_subnet" {
  type = map
  default = {
    us-west-2a = "172.71.1.0/24"
  }
}

variable "client_machine_type" {
  default = "m6a.large"
}

variable "client_machine_image" {
  // Ubuntu 24.04 LTS
  default = "ami-0cf2b4e024cdb6960"
}

variable "hydra_image" {
  default = "europe-docker.pkg.dev/ory-artifacts/ory-enterprise/hydra-oel"
}

variable "hydra_release_tag" {
  default = "latest"
}

variable "hydra_admin_port" {
  default = 4445
}

variable "hydra_public_port" {
  default = 4444
}

variable "kratos_image" {
  default = "oryd/kratos" //http://europe-docker.pkg.dev/ory-artifacts/ory-enterprise-kratos/kratos-oel
}

variable "kratos_release_tag" {
  default = "latest"
}

variable "keto_image" {
  default = "oryd/keto"
}

variable "keto_release_tag" {
  default = "latest"
}

variable "keto_read_port" {
  default = 4466
}

variable "keto_write_port" {
  default = 4467
}

variable "organization_name" {
  description = "Organization Name"
  default = "partner_sales"
}

variable "cluster_license" {
  description = "Cluster License"
}
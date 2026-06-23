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
  default     = "demo.datacrafterslab.com"
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
  default = "https://binaries.cockroachdb.com/cockroach-v26.1.3.linux-amd64.tgz"
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

# When the operator's AWS principal lacks iam:CreateRole (typical for SSO
# permission sets), set this to an existing role name that trusts both
# eks.amazonaws.com and ec2.amazonaws.com and carries the EKS cluster + worker
# + CNI + ECR-read managed policies. The EKS module will then skip per-cluster
# role creation and reuse this role for both cluster + node-group ARNs.
variable "shared_eks_iam_role_name" {
  description = "Existing IAM role to reuse as both EKS cluster role and node-group role. Empty string creates per-deployment roles (requires iam:CreateRole)."
  type        = string
  default     = ""
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

############################################################
# CRDB Node Map
#
# Seeds system.locations with lat/long for every region and
# zone used by the deployment so the DB Console renders nodes
# on a world map. UPSERT keeps the statements idempotent across
# both bastions. Coordinates are the canonical values from
# CockroachDB docs (https://www.cockroachlabs.com/docs/stable/enable-node-map).
############################################################

variable "crdb_node_map_sql" {
  description = "UPSERT statements seeding system.locations so the DB Console Node Map renders coordinates for every region and zone. Applied next to the license SET when multi_region = true."
  type        = string
  default     = <<-EOT
    UPSERT INTO system.locations VALUES
      -- North America
      ('region', 'us-east-1',       37.478397,  -76.453077),
      ('region', 'us-east-2',       40.417287,  -82.907123),
      ('region', 'us-west-1',       38.837522, -120.895824),
      ('region', 'us-west-2',       43.804133, -120.554201),
      ('region', 'us-gov-east-1',   37.478397,  -76.453077),
      ('region', 'us-gov-west-1',   43.804133, -120.554201),
      ('region', 'ca-central-1',    56.130366, -106.346771),
      ('region', 'ca-west-1',       51.044734, -114.071883),
      ('region', 'mx-central-1',    19.432608,  -99.133209),
      -- South America
      ('region', 'sa-east-1',      -23.550520,  -46.633308),
      -- Europe
      ('region', 'eu-west-1',       53.142367,   -7.692054),
      ('region', 'eu-west-2',       51.507351,   -0.127758),
      ('region', 'eu-west-3',       48.856613,    2.352222),
      ('region', 'eu-central-1',    50.110924,    8.682127),
      ('region', 'eu-central-2',    47.376888,    8.541694),
      ('region', 'eu-north-1',      59.329323,   18.068581),
      ('region', 'eu-south-1',      45.464203,    9.189982),
      ('region', 'eu-south-2',      40.416775,   -3.703790),
      -- Middle East
      ('region', 'me-south-1',      26.066700,   50.557700),
      ('region', 'me-central-1',    23.424076,   53.847818),
      ('region', 'il-central-1',    32.085300,   34.781800),
      -- Africa
      ('region', 'af-south-1',     -33.924870,   18.424055),
      -- Asia Pacific
      ('region', 'ap-east-1',       22.396428,  114.109497),
      ('region', 'ap-east-2',       22.396428,  114.109497),
      ('region', 'ap-south-1',      19.075984,   72.877656),
      ('region', 'ap-south-2',      17.385044,   78.486671),
      ('region', 'ap-southeast-1',   1.352083,  103.819836),
      ('region', 'ap-southeast-2', -33.868820,  151.209296),
      ('region', 'ap-southeast-3',  -6.200000,  106.816666),
      ('region', 'ap-southeast-4', -37.813629,  144.963058),
      ('region', 'ap-southeast-5',   3.139003,  101.686852),
      ('region', 'ap-southeast-6', -41.276825,  174.777969),
      ('region', 'ap-southeast-7',  13.756331,  100.501762),
      ('region', 'ap-northeast-1',  35.689487,  139.691711),
      ('region', 'ap-northeast-2',  37.566535,  126.977969),
      ('region', 'ap-northeast-3',  34.693738,  135.502165),
      -- Zones (a/b/c per region; extra letters fall back to the region row)
      ('zone',   'us-east-1a',      37.478397,  -76.453077),
      ('zone',   'us-east-1b',      37.478397,  -76.453077),
      ('zone',   'us-east-1c',      37.478397,  -76.453077),
      ('zone',   'us-east-2a',      40.417287,  -82.907123),
      ('zone',   'us-east-2b',      40.417287,  -82.907123),
      ('zone',   'us-east-2c',      40.417287,  -82.907123),
      ('zone',   'us-west-1a',      38.837522, -120.895824),
      ('zone',   'us-west-1b',      38.837522, -120.895824),
      ('zone',   'us-west-1c',      38.837522, -120.895824),
      ('zone',   'us-west-2a',      43.804133, -120.554201),
      ('zone',   'us-west-2b',      43.804133, -120.554201),
      ('zone',   'us-west-2c',      43.804133, -120.554201),
      ('zone',   'ca-central-1a',   56.130366, -106.346771),
      ('zone',   'ca-central-1b',   56.130366, -106.346771),
      ('zone',   'ca-central-1c',   56.130366, -106.346771),
      ('zone',   'ca-west-1a',      51.044734, -114.071883),
      ('zone',   'ca-west-1b',      51.044734, -114.071883),
      ('zone',   'ca-west-1c',      51.044734, -114.071883),
      ('zone',   'mx-central-1a',   19.432608,  -99.133209),
      ('zone',   'mx-central-1b',   19.432608,  -99.133209),
      ('zone',   'mx-central-1c',   19.432608,  -99.133209),
      ('zone',   'sa-east-1a',     -23.550520,  -46.633308),
      ('zone',   'sa-east-1b',     -23.550520,  -46.633308),
      ('zone',   'sa-east-1c',     -23.550520,  -46.633308),
      ('zone',   'eu-west-1a',      53.142367,   -7.692054),
      ('zone',   'eu-west-1b',      53.142367,   -7.692054),
      ('zone',   'eu-west-1c',      53.142367,   -7.692054),
      ('zone',   'eu-west-2a',      51.507351,   -0.127758),
      ('zone',   'eu-west-2b',      51.507351,   -0.127758),
      ('zone',   'eu-west-2c',      51.507351,   -0.127758),
      ('zone',   'eu-west-3a',      48.856613,    2.352222),
      ('zone',   'eu-west-3b',      48.856613,    2.352222),
      ('zone',   'eu-west-3c',      48.856613,    2.352222),
      ('zone',   'eu-central-1a',   50.110924,    8.682127),
      ('zone',   'eu-central-1b',   50.110924,    8.682127),
      ('zone',   'eu-central-1c',   50.110924,    8.682127),
      ('zone',   'eu-central-2a',   47.376888,    8.541694),
      ('zone',   'eu-central-2b',   47.376888,    8.541694),
      ('zone',   'eu-central-2c',   47.376888,    8.541694),
      ('zone',   'eu-north-1a',     59.329323,   18.068581),
      ('zone',   'eu-north-1b',     59.329323,   18.068581),
      ('zone',   'eu-north-1c',     59.329323,   18.068581),
      ('zone',   'eu-south-1a',     45.464203,    9.189982),
      ('zone',   'eu-south-1b',     45.464203,    9.189982),
      ('zone',   'eu-south-1c',     45.464203,    9.189982),
      ('zone',   'eu-south-2a',     40.416775,   -3.703790),
      ('zone',   'eu-south-2b',     40.416775,   -3.703790),
      ('zone',   'eu-south-2c',     40.416775,   -3.703790),
      ('zone',   'me-south-1a',     26.066700,   50.557700),
      ('zone',   'me-south-1b',     26.066700,   50.557700),
      ('zone',   'me-south-1c',     26.066700,   50.557700),
      ('zone',   'me-central-1a',   23.424076,   53.847818),
      ('zone',   'me-central-1b',   23.424076,   53.847818),
      ('zone',   'me-central-1c',   23.424076,   53.847818),
      ('zone',   'il-central-1a',   32.085300,   34.781800),
      ('zone',   'il-central-1b',   32.085300,   34.781800),
      ('zone',   'il-central-1c',   32.085300,   34.781800),
      ('zone',   'af-south-1a',    -33.924870,   18.424055),
      ('zone',   'af-south-1b',    -33.924870,   18.424055),
      ('zone',   'af-south-1c',    -33.924870,   18.424055),
      ('zone',   'ap-east-1a',      22.396428,  114.109497),
      ('zone',   'ap-east-1b',      22.396428,  114.109497),
      ('zone',   'ap-east-1c',      22.396428,  114.109497),
      ('zone',   'ap-south-1a',     19.075984,   72.877656),
      ('zone',   'ap-south-1b',     19.075984,   72.877656),
      ('zone',   'ap-south-1c',     19.075984,   72.877656),
      ('zone',   'ap-south-2a',     17.385044,   78.486671),
      ('zone',   'ap-south-2b',     17.385044,   78.486671),
      ('zone',   'ap-south-2c',     17.385044,   78.486671),
      ('zone',   'ap-southeast-1a',  1.352083,  103.819836),
      ('zone',   'ap-southeast-1b',  1.352083,  103.819836),
      ('zone',   'ap-southeast-1c',  1.352083,  103.819836),
      ('zone',   'ap-southeast-2a',-33.868820,  151.209296),
      ('zone',   'ap-southeast-2b',-33.868820,  151.209296),
      ('zone',   'ap-southeast-2c',-33.868820,  151.209296),
      ('zone',   'ap-southeast-3a', -6.200000,  106.816666),
      ('zone',   'ap-southeast-3b', -6.200000,  106.816666),
      ('zone',   'ap-southeast-3c', -6.200000,  106.816666),
      ('zone',   'ap-southeast-4a',-37.813629,  144.963058),
      ('zone',   'ap-southeast-4b',-37.813629,  144.963058),
      ('zone',   'ap-southeast-4c',-37.813629,  144.963058),
      ('zone',   'ap-southeast-5a',  3.139003,  101.686852),
      ('zone',   'ap-southeast-5b',  3.139003,  101.686852),
      ('zone',   'ap-southeast-5c',  3.139003,  101.686852),
      ('zone',   'ap-northeast-1a', 35.689487,  139.691711),
      ('zone',   'ap-northeast-1b', 35.689487,  139.691711),
      ('zone',   'ap-northeast-1c', 35.689487,  139.691711),
      ('zone',   'ap-northeast-2a', 37.566535,  126.977969),
      ('zone',   'ap-northeast-2b', 37.566535,  126.977969),
      ('zone',   'ap-northeast-2c', 37.566535,  126.977969),
      ('zone',   'ap-northeast-3a', 34.693738,  135.502165),
      ('zone',   'ap-northeast-3b', 34.693738,  135.502165),
      ('zone',   'ap-northeast-3c', 34.693738,  135.502165);
  EOT
}

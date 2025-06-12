# Create VPC
resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge("${var.resource_tags}",{
    Name = "${var.deployment_name}-eks-vpc"
  })
}

# Subnet Public
resource "aws_subnet" "public-subnets" {
  count                   = length(var.subnets_cidrs)
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = values(var.subnets_cidrs)[count.index]
  availability_zone       = keys(var.subnets_cidrs)[count.index]
  map_public_ip_on_launch = true

  tags = merge("${var.resource_tags}",{
    Name = "${var.deployment_name}-eks-public-subnet-${count.index}",
    "kubernetes.io/role/elb" = "1"
  })
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = merge("${var.resource_tags}",{
    Name = "${var.deployment_name}-eks-igw"
  })
}

# Route Tables
resource "aws_route_table" "rt-public" {
  vpc_id = aws_vpc.vpc.id
  tags = merge("${var.resource_tags}",{
    Name = "${var.deployment_name}-eks-rt-public"
  })
}

# Associate the main route table to the VPC
resource "aws_main_route_table_association" "rt-main" {
  vpc_id         = aws_vpc.vpc.id
  route_table_id = aws_route_table.rt-public.id
}

# Associate Public Subnets with Route Table for Internet Gateway
resource "aws_route_table_association" "rt-to-public-subnet" {
  count = length(var.subnets_cidrs)
  subnet_id = aws_subnet.public-subnets[count.index].id
  route_table_id = aws_route_table.rt-public.id
}

############################################################
# Route Entries
resource "aws_route" "public-allipv4" {
  route_table_id         = aws_route_table.rt-public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route" "public-allowipv6" {
  route_table_id              = aws_route_table.rt-public.id
  destination_ipv6_cidr_block = "::/0"
  gateway_id                  = aws_internet_gateway.igw.id
}

# Create Security Group
resource "aws_security_group" "cluster" {
  name        = "${var.deployment_name}-eks-sg"
  description = "AWS security group for EKS cluster"
  vpc_id      = aws_vpc.vpc.id

  # Input
  ingress {
    from_port   = "1"
    to_port     = "65365"
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Output
  egress {
    from_port   = 0             # any port
    to_port     = 0             # any port
    protocol    = "-1"          # any protocol
    cidr_blocks = ["0.0.0.0/0"] # any destination
  }

  # ICMP Ping
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = merge("${var.resource_tags}",{
    Name = "${var.deployment_name}-eks-sg"
  })
}

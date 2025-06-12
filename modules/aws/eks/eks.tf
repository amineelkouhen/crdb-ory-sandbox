terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# EKS Cluster Resources
resource "aws_eks_cluster" "eks" {
  name                 = "${var.deployment_name}-ory-cluster"
  version              = var.cluster_version
  role_arn             = aws_iam_role.cluster.arn

  vpc_config {
    endpoint_public_access  = true
    security_group_ids = [aws_security_group.cluster.id]
    subnet_ids         = aws_subnet.public-subnets.*.id
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.cluster-AmazonEKSServicePolicy,
  ]
}


resource "aws_eks_node_group" "eks-node-group" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "${var.deployment_name}-default-node-group"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = aws_subnet.public-subnets.*.id
  capacity_type   = "ON_DEMAND"
  node_group_name_prefix = null #"Creates a unique name beginning with the specified prefix. Conflicts with node_group_name"
  scaling_config {
    desired_size  = var.cluster_size
    max_size      = var.cluster_size
    min_size      = 1
  }
  update_config {
    max_unavailable = 1
  }
  instance_types = [var.machine_type]
  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_eks_cluster.eks,
    aws_iam_role_policy_attachment.node-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node-AmazonEKS_CNI_Policy
  ]
  tags = {
    Name = "${var.deployment_name}-default-node-group"
  }
}
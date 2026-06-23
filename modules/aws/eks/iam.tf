# IAM
#
# Default path (var.shared_iam_role_name = ""): create per-deployment cluster
# and node roles + instance profile. This preserves the original behavior for
# callers that have iam:CreateRole.
#
# Shared-role path (var.shared_iam_role_name = "<name>"): look up an existing
# role and reuse it as both the cluster and node-group role. The shared role
# must trust both eks.amazonaws.com and ec2.amazonaws.com and carry the
# AmazonEKSClusterPolicy, AmazonEKSWorkerNodePolicy, AmazonEKS_CNI_Policy, and
# AmazonEC2ContainerRegistryReadOnly managed policies.

data "aws_iam_role" "shared" {
  count = var.shared_iam_role_name != "" ? 1 : 0
  name  = var.shared_iam_role_name
}

// Cluster
resource "aws_iam_role" "cluster" {
  count = var.shared_iam_role_name == "" ? 1 : 0
  name  = "${var.deployment_name}-eks-cluster-role"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "cluster-AmazonEKSClusterPolicy" {
  count      = var.shared_iam_role_name == "" ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster[0].name
}

resource "aws_iam_role_policy_attachment" "cluster-AmazonEKSServicePolicy" {
  count      = var.shared_iam_role_name == "" ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.cluster[0].name
}

// NODES
resource "aws_iam_role" "node" {
  count = var.shared_iam_role_name == "" ? 1 : 0
  name  = "${var.deployment_name}-eks-node-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "node-AmazonEKSWorkerNodePolicy" {
  count      = var.shared_iam_role_name == "" ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node[0].name
}

resource "aws_iam_role_policy_attachment" "node-AmazonEKS_CNI_Policy" {
  count      = var.shared_iam_role_name == "" ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node[0].name
}

resource "aws_iam_role_policy_attachment" "node-AmazonEC2ContainerRegistryReadOnly" {
  count      = var.shared_iam_role_name == "" ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node[0].name
}

resource "aws_iam_instance_profile" "node" {
  count = var.shared_iam_role_name == "" ? 1 : 0
  name  = "${var.deployment_name}-eks-node-instance-profile"
  role  = aws_iam_role.node[0].name
}

locals {
  cluster_role_arn = var.shared_iam_role_name != "" ? data.aws_iam_role.shared[0].arn : aws_iam_role.cluster[0].arn
  node_role_arn    = var.shared_iam_role_name != "" ? data.aws_iam_role.shared[0].arn : aws_iam_role.node[0].arn
}

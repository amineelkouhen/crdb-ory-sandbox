output "cluster_name" {
  value       = aws_eks_cluster.eks.id
  description = "The name of the created EKS Ory cluster."
}

output "cluster_version" {
  value       = aws_eks_cluster.eks.platform_version
  description = "The version of Kubernetes running on the EKS Ory cluster."
}

output "cluster_endpoint" {
  value       = aws_eks_cluster.eks.endpoint
  description = "The endpoint for the EKS Kubernetes API server."
}

data "aws_instances" "eks_nodes" {
  instance_tags = {
    "eks:cluster-name" = aws_eks_cluster.eks.id
  }
  instance_state_names = ["running"]
  depends_on = [aws_eks_node_group.eks-node-group]
}

output "eks_nodes_private_ips" {
  value = data.aws_instances.eks_nodes.private_ips[*]
}

output "eks_nodes_public_ips" {
  value = data.aws_instances.eks_nodes.public_ips[*]
}
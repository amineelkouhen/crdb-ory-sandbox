output "cluster_master_dns" {
  value = "${var.subdomain}.cluster.${var.hosted_zone}"
}

output "routing_policy" {
  value = aws_route53_traffic_policy_instance.policy-instance
}

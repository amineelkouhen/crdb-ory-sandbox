############################################################
# Public DNS + ACM for the multi-region deployment
#
# Subdomain layout (with deployment_name = "amine-ory"):
#   hydra-public.amine-ory.sko-iam-demo.com
#   hydra-admin.amine-ory.sko-iam-demo.com
#   kratos-public.amine-ory.sko-iam-demo.com
#   kratos-admin.amine-ory.sko-iam-demo.com
#   keto-read.amine-ory.sko-iam-demo.com
#   keto-write.amine-ory.sko-iam-demo.com
#   crdb.amine-ory.sko-iam-demo.com
#
# Each subdomain has two latency-routed ALIAS A records (one per region),
# pointing at the regional NLB. CRDB records use the network module's NLB
# (created up-front by Terraform). Ory records use the NLBs that the Helm
# charts create when the bastion finishes installing the services; a
# null_resource SSH-polls each bastion until all six LBs are ready so the
# aws_lb data lookups never race the chart.
############################################################

locals {
  deployment_subdomain = lower(replace(var.deployment_name, "_", "-"))

  ory_services = [
    "ory-hydra-public",
    "ory-hydra-admin",
    "ory-kratos-public",
    "ory-kratos-admin",
    "ory-keto-read",
    "ory-keto-write",
  ]

  endpoint_subdomains = {
    "ory-hydra-public"  = "hydra-public"
    "ory-hydra-admin"   = "hydra-admin"
    "ory-kratos-public" = "kratos-public"
    "ory-kratos-admin"  = "kratos-admin"
    "ory-keto-read"     = "keto-read"
    "ory-keto-write"    = "keto-write"
  }
}

data "aws_route53_zone" "primary" {
  provider     = aws.providerR1
  name         = var.hosted_zone
  private_zone = false
}

############################################################
# ACM wildcard certificate per region
#
# Pre-provisioned for future TLS termination (Istio ingress
# gateway or ALB Ingress Controller). The sandbox currently
# serves HTTP on the NLBs; the certificate ARN is exported so
# a follow-up change can attach it without re-validating DNS.
############################################################

resource "aws_acm_certificate" "wildcard_r1" {
  provider          = aws.providerR1
  domain_name       = "*.${local.deployment_subdomain}.${var.hosted_zone}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate" "wildcard_r2" {
  provider          = aws.providerR2
  domain_name       = "*.${local.deployment_subdomain}.${var.hosted_zone}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation_r1" {
  provider = aws.providerR1
  for_each = {
    for dvo in aws_acm_certificate.wildcard_r1.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.primary.zone_id
}

resource "aws_route53_record" "cert_validation_r2" {
  provider = aws.providerR1
  for_each = {
    for dvo in aws_acm_certificate.wildcard_r2.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.primary.zone_id
}

resource "aws_acm_certificate_validation" "wildcard_r1" {
  provider                = aws.providerR1
  certificate_arn         = aws_acm_certificate.wildcard_r1.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation_r1 : record.fqdn]
}

resource "aws_acm_certificate_validation" "wildcard_r2" {
  provider                = aws.providerR2
  certificate_arn         = aws_acm_certificate.wildcard_r2.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation_r2 : record.fqdn]
}

############################################################
# Wait for the Ory NLBs to be provisioned by Helm
############################################################

resource "null_resource" "wait_for_ory_lbs_r1" {
  depends_on = [module.bastion-1]

  triggers = {
    bastion_id = module.bastion-1.public-ip
  }

  connection {
    host        = module.bastion-1.public-ip
    type        = "ssh"
    user        = var.ssh_user
    private_key = file(var.ssh_private_key)
    timeout     = "20m"
  }

  provisioner "remote-exec" {
    inline = [
      "set -e",
      "for svc in ory-hydra-public ory-hydra-admin ory-kratos-public ory-kratos-admin ory-keto-read ory-keto-write; do until [ -n \"$(kubectl get svc -n ory $svc -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)\" ]; do echo \"waiting for $svc in r1...\"; sleep 15; done; echo \"$svc in r1 ready\"; done",
    ]
  }
}

resource "null_resource" "wait_for_ory_lbs_r2" {
  depends_on = [module.bastion-2]

  triggers = {
    bastion_id = module.bastion-2.public-ip
  }

  connection {
    host        = module.bastion-2.public-ip
    type        = "ssh"
    user        = var.ssh_user
    private_key = file(var.ssh_private_key)
    timeout     = "20m"
  }

  provisioner "remote-exec" {
    inline = [
      "set -e",
      "for svc in ory-hydra-public ory-hydra-admin ory-kratos-public ory-kratos-admin ory-keto-read ory-keto-write; do until [ -n \"$(kubectl get svc -n ory $svc -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)\" ]; do echo \"waiting for $svc in r2...\"; sleep 15; done; echo \"$svc in r2 ready\"; done",
    ]
  }
}

############################################################
# Look up the per-service NLBs after Helm has provisioned them
############################################################

data "aws_lb" "ory_r1" {
  for_each = toset(local.ory_services)
  provider = aws.providerR1

  tags = {
    "kubernetes.io/service-name"                                 = "ory/${each.value}"
    "kubernetes.io/cluster/${module.ory-cluster-1.cluster_name}" = "owned"
  }

  depends_on = [null_resource.wait_for_ory_lbs_r1]
}

data "aws_lb" "ory_r2" {
  for_each = toset(local.ory_services)
  provider = aws.providerR2

  tags = {
    "kubernetes.io/service-name"                                 = "ory/${each.value}"
    "kubernetes.io/cluster/${module.ory-cluster-2.cluster_name}" = "owned"
  }

  depends_on = [null_resource.wait_for_ory_lbs_r2]
}

############################################################
# Latency-routed records for the six Ory endpoints
############################################################

resource "aws_route53_record" "ory_r1" {
  for_each = local.endpoint_subdomains
  provider = aws.providerR1

  zone_id        = data.aws_route53_zone.primary.zone_id
  name           = "${each.value}.${local.deployment_subdomain}.${var.hosted_zone}"
  type           = "A"
  set_identifier = var.regions[0]

  latency_routing_policy {
    region = var.regions[0]
  }

  alias {
    name                   = data.aws_lb.ory_r1[each.key].dns_name
    zone_id                = data.aws_lb.ory_r1[each.key].zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "ory_r2" {
  for_each = local.endpoint_subdomains
  provider = aws.providerR1

  zone_id        = data.aws_route53_zone.primary.zone_id
  name           = "${each.value}.${local.deployment_subdomain}.${var.hosted_zone}"
  type           = "A"
  set_identifier = var.regions[1]

  latency_routing_policy {
    region = var.regions[1]
  }

  alias {
    name                   = data.aws_lb.ory_r2[each.key].dns_name
    zone_id                = data.aws_lb.ory_r2[each.key].zone_id
    evaluate_target_health = true
  }
}

############################################################
# Latency-routed records for the CRDB SQL gateway
############################################################

resource "aws_route53_record" "crdb_r1" {
  provider = aws.providerR1

  zone_id        = data.aws_route53_zone.primary.zone_id
  name           = "crdb.${local.deployment_subdomain}.${var.hosted_zone}"
  type           = "A"
  set_identifier = var.regions[0]

  latency_routing_policy {
    region = var.regions[0]
  }

  alias {
    name                   = module.network-vpc-1.nlb_dns_name
    zone_id                = module.network-vpc-1.nlb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "crdb_r2" {
  provider = aws.providerR1

  zone_id        = data.aws_route53_zone.primary.zone_id
  name           = "crdb.${local.deployment_subdomain}.${var.hosted_zone}"
  type           = "A"
  set_identifier = var.regions[1]

  latency_routing_policy {
    region = var.regions[1]
  }

  alias {
    name                   = module.network-vpc-2.nlb_dns_name
    zone_id                = module.network-vpc-2.nlb_zone_id
    evaluate_target_health = true
  }
}

############################################################
# Outputs
############################################################

output "ory_endpoint_urls" {
  description = "Public latency-routed URLs for each Ory service."
  value = {
    hydra_public  = "http://hydra-public.${local.deployment_subdomain}.${var.hosted_zone}:${var.hydra_public_port}/"
    hydra_admin   = "http://hydra-admin.${local.deployment_subdomain}.${var.hosted_zone}:${var.hydra_admin_port}/"
    kratos_public = "http://kratos-public.${local.deployment_subdomain}.${var.hosted_zone}:${var.kratos_public_port}/"
    kratos_admin  = "http://kratos-admin.${local.deployment_subdomain}.${var.hosted_zone}:${var.kratos_admin_port}/"
    keto_read     = "http://keto-read.${local.deployment_subdomain}.${var.hosted_zone}:${var.keto_read_port}/"
    keto_write    = "http://keto-write.${local.deployment_subdomain}.${var.hosted_zone}:${var.keto_write_port}/"
  }
}

output "crdb_sql_url" {
  description = "Public latency-routed CRDB SQL gateway."
  value       = "postgresql://root@crdb.${local.deployment_subdomain}.${var.hosted_zone}:26257/defaultdb?sslmode=disable"
}

output "wildcard_cert_arns" {
  description = "ACM wildcard certificate ARNs per region (for follow-up TLS termination work)."
  value = {
    region_1 = aws_acm_certificate_validation.wildcard_r1.certificate_arn
    region_2 = aws_acm_certificate_validation.wildcard_r2.certificate_arn
  }
}

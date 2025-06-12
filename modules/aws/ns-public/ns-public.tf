terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "aws_route53_zone" "hosted_zone" {
  name         = "${var.hosted_zone}"
  private_zone = false
}

resource "aws_route53_traffic_policy" "policy" {
  name     = "${var.subdomain}-policy"
  document = <<EOF
{
   "AWSPolicyFormatVersion":"2023-05-09",
   "RecordType":"A",
   "Endpoints":{
      "ep-1":{
         "Type":"network-load-balancer",
         "Value":"${var.nlb_list[0]}"
      },
      "ep-2":{
         "Type":"network-load-balancer",
         "Value":"${var.nlb_list[1]}"
      },
      "ep-3":{
         "Type":"network-load-balancer",
         "Value":"${var.nlb_list[2]}"
      }
   },
   "Rules":{
      "rule-1":{
         "RuleType":"weighted",
         "Items":[
            {
               "Weight":"50",
               "EvaluateTargetHealth":true,
               "EndpointReference":"ep-1"
            },
            {
               "Weight":"50",
               "EvaluateTargetHealth":true,
               "EndpointReference":"ep-2"
            },
            {
               "Weight":"50",
               "EvaluateTargetHealth":true,
               "EndpointReference":"ep-3"
            }
         ]
      }
   },
   "StartRule":"rule-1"
}
EOF
}

resource "aws_route53_traffic_policy_instance" "policy-instance" {
  name                   = "${var.subdomain}.cluster.${var.hosted_zone}"
  traffic_policy_id      = aws_route53_traffic_policy.policy.id
  traffic_policy_version = 1
  hosted_zone_id         = data.aws_route53_zone.hosted_zone.zone_id
  ttl                    = 60
}
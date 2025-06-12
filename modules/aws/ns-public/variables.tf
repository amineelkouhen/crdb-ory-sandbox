variable "subdomain" {
  description = "The DNS custom subdomain"
  type        = string
}

variable "hosted_zone" {
  description = "Hosted Zone where the record will be added"
  type        = string
}

variable "nlb_list" {
  description = "List of NLB DNS"
  type        = list(string)
}

variable "resource_tags" {
  description = "hash with tags for all resources"
}

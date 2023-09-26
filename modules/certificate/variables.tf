variable "zone_id" {
  description = "Route53 zone id"
  type        = string
}

variable "ttl" {
  description = "TTL for the DNS record"
  default     = 60
  type        = number
}

variable "domain_name" {
  type        = string
  description = "domain_name to be used with the certificate"
}

variable "subject_alternative_names" {
  description = "Set of domains that should be SANs in the issued certificate"
  type        = list(string)
  default     = []
}

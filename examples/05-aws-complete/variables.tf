variable "region" {
  description = "AWS region to use with all resources"
  type        = string
  default     = "eu-west-1"
}

variable "name_prefix" {
  type        = string
  description = "name prefix to be used for unique resource names"
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
}

variable "subnets" {
  description = "VPC subnets CIDRs"
  type = object({
    public      = list(string)
    private     = list(string)
    database    = list(string)
    elasticache = list(string)
  })
}

variable "notification_emails" {
  type        = list(string)
  description = "List of emails where to send monitoring notifications"
  default     = []
}

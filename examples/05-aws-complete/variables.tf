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

variable "retention_in_days" {
  description = "log retention in days to be used throughout the module"
  type        = number
  default     = 7
}

variable "redis" {
  description = "AWS ElastiCache (Redis)"
  type = object({
    node_type      = string
    node_num       = number
    cluster_id     = string
    engine_version = string
  })

  default = {
    node_type      = "cache.t3.micro"
    node_num       = 1
    cluster_id     = "redis"
    engine_version = "6.2"
  }
}

variable "region" {
  description = "AWS region to use with all resources"
  type        = string
  default     = "eu-west-1"
}

variable "name_prefix" {
  description = "Prefix for the trail, bucket and log group names"
  type        = string
}

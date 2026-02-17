variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for encryption"
  type        = string
}

variable "retention_in_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 365
}

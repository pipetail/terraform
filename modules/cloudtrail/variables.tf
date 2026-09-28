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

variable "cloudwatch_role_name" {
  description = "Name of the IAM role CloudTrail assumes to deliver events to CloudWatch Logs. IAM role names are unique per account, so set a distinct name for each instance of this module in one account."
  type        = string
  default     = "cloudtrail-cloudwatch"
}

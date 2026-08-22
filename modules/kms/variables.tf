variable "key_administrator_arns" {
  description = "IAM role or user ARNs allowed to administer the KMS key"
  type        = set(string)
  nullable    = false

  validation {
    condition     = length(var.key_administrator_arns) > 0
    error_message = "key_administrator_arns must contain at least one IAM role or user ARN."
  }

  validation {
    condition = alltrue([
      for arn in var.key_administrator_arns : can(regex("^arn:(aws|aws-cn|aws-us-gov|aws-iso|aws-iso-b|aws-iso-e|aws-iso-f):iam::[0-9]{12}:(role|user)/[^[:space:]]+$", arn))
    ])
    error_message = "key_administrator_arns must contain only IAM role or user ARNs."
  }
}

variable "key_user_arns" {
  description = "IAM role or user ARNs allowed to use the KMS key"
  type        = set(string)
  default     = []
  nullable    = false

  validation {
    condition = alltrue([
      for arn in var.key_user_arns : can(regex("^arn:(aws|aws-cn|aws-us-gov|aws-iso|aws-iso-b|aws-iso-e|aws-iso-f):iam::[0-9]{12}:(role|user)/[^[:space:]]+$", arn))
    ])
    error_message = "key_user_arns must contain only IAM role or user ARNs."
  }
}

variable "cloudwatch_log_group_arn_patterns" {
  description = "CloudWatch Logs log group ARN patterns allowed to use the KMS key"
  type        = set(string)
  default     = []
  nullable    = false

  validation {
    condition = alltrue([
      for arn in var.cloudwatch_log_group_arn_patterns : can(regex("^arn:(aws|aws-cn|aws-us-gov|aws-iso|aws-iso-b|aws-iso-e|aws-iso-f):logs:[a-z0-9-]+:[0-9]{12}:log-group:[A-Za-z0-9._/#*-]+$", arn))
    ])
    error_message = "cloudwatch_log_group_arn_patterns must contain only CloudWatch Logs log group ARN patterns."
  }
}

variable "cloudtrail_trail_arns" {
  description = "CloudTrail trail ARNs allowed to use the KMS key"
  type        = set(string)
  default     = []
  nullable    = false

  validation {
    condition = alltrue([
      for arn in var.cloudtrail_trail_arns : can(regex("^arn:(aws|aws-cn|aws-us-gov|aws-iso|aws-iso-b|aws-iso-e|aws-iso-f):cloudtrail:[a-z0-9-]+:[0-9]{12}:trail/[A-Za-z0-9][A-Za-z0-9._-]{1,126}[A-Za-z0-9]$", arn))
    ])
    error_message = "cloudtrail_trail_arns must contain only exact CloudTrail trail ARNs."
  }
}

variable "region" {
  description = "AWS region name for the KMS key"
  type        = string
}

variable "key_rotation_enabled" {
  description = "Enable automatic key rotation"
  type        = bool
  default     = true
}

variable "deletion_window_in_days" {
  description = "Duration in days after which the key is deleted after destruction"
  type        = number
  default     = 10
}

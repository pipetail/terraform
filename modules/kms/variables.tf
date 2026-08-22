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

variable "principal_arn" {
  type        = string
  description = "ARN of the IAM role allowed to assume this role"
  default     = "arn:aws:iam::680177765279:role/gate-host-agent"

  validation {
    condition     = can(regex("^arn:aws:iam::[0-9]{12}:role/[^*]+$", var.principal_arn))
    error_message = "principal_arn must be the ARN of one IAM role; an account root or wildcard would let every principal in that account assume this role."
  }
}

variable "role_name" {
  type        = string
  description = "Name of the IAM role to create"
  default     = "pipetailInvestigation"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to the IAM role"
  default     = {}
}

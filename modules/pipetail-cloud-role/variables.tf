variable "external_id" {
  type        = string
  description = "External ID minted by pipetail.cloud for this account connection. Unique per connected account — copy it from the portal's Connect account flow."

  validation {
    condition     = length(var.external_id) > 0
    error_message = "external_id must be the value pipetail.cloud minted for this account; an empty string would let any principal in the portal account assume this role."
  }
}

variable "portal_aws_account_id" {
  type        = string
  description = "AWS account ID pipetail.cloud assumes this role from"
  default     = "680177765279"

  validation {
    condition     = can(regex("^[0-9]{12}$", var.portal_aws_account_id))
    error_message = "portal_aws_account_id must be a 12-digit AWS account ID."
  }
}

variable "alerting_log_group" {
  type        = string
  description = "CloudWatch log group of the aws-events-to-slack Lambda, read for the forwarded-event timeline. Change it only if the function was deployed under a different name."
  default     = "/aws/lambda/aws-events-to-slack"
}

variable "role_name" {
  type        = string
  description = "Name of the IAM role to create"
  default     = "pipetailCloud"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to the IAM role"
  default     = {}
}

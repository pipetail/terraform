variable "api_endpoint" {
  type        = string
  description = "pipetail.cloud endpoint the events are posted to. The default is the portal's ingest URL; override it only if pipetail.cloud gives you a different one."
  default     = "https://api.pipetail.cloud/ingest/aws-health"

  validation {
    condition     = can(regex("^https://", var.api_endpoint))
    error_message = "api_endpoint must be an https:// URL. EventBridge API destinations invoke HTTPS endpoints only."
  }
}

variable "name" {
  type        = string
  description = "Base name for the EventBridge connection, API destination, rule and dead-letter queue (suffixed -dlq). All four are Regional, so the same name is safe in every Region; the IAM role is global and is created from this as a prefix with a unique suffix appended by AWS, so instantiating the module in several Regions never collides on it."
  default     = "pipetail-cloud-health-ingest"

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]{1,37}$", var.name))
    error_message = "name must be 1-37 letters, digits, hyphens or underscores: SQS rejects anything else in the dead-letter queue name, and 37 leaves room for the suffix AWS appends to the IAM role name."
  }
}

variable "target_id" {
  type        = string
  description = "Target id on the EventBridge rule. Changing a target's id forces EventBridge to replace it, so set this to the existing id when adopting a target that was created outside the module; leave the default everywhere else."
  default     = "pipetail-cloud-ingest"

  validation {
    condition     = can(regex("^[.\\-_A-Za-z0-9]{1,64}$", var.target_id))
    error_message = "target_id must be 1-64 characters of letters, digits, dots, hyphens or underscores, per the EventBridge PutTargets constraints."
  }
}

variable "create_dlq" {
  type        = bool
  description = "Create an SQS dead-letter queue holding events EventBridge could not deliver. With this off, an event EventBridge gives up on is dropped and no copy of it exists anywhere."
  default     = true
}

variable "invocation_rate_limit_per_second" {
  type        = number
  description = "Ceiling on how many events per second EventBridge sends to the endpoint. AWS Health is low-volume, so the default leaves ample headroom. Events above the ceiling back up behind it and expire once they pass the target's maximum event age."
  default     = 10

  validation {
    condition     = var.invocation_rate_limit_per_second >= 1
    error_message = "invocation_rate_limit_per_second must be at least 1."
  }
}

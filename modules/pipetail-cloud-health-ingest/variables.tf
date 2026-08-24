variable "ingest_key" {
  type        = string
  description = "AWS Health ingest key generated in pipetail.cloud under Settings, shown once when you generate it. Terraform keeps it in state and hands it to EventBridge, which stores it in a Secrets Manager secret it manages for the connection; a key rotated in the portal reaches EventBridge only on the next apply."
  sensitive   = true

  validation {
    condition     = length(var.ingest_key) > 0
    error_message = "ingest_key must be the key generated in pipetail.cloud Settings; an empty value is accepted by EventBridge and every delivery then fails to authenticate."
  }
}

variable "api_endpoint" {
  type        = string
  description = "pipetail.cloud endpoint the events are posted to. The default is the portal's ingest URL — override it only if pipetail.cloud gives you a different one."
  default     = "https://api.pipetail.cloud/ingest/aws-health"

  validation {
    condition     = can(regex("^https://", var.api_endpoint))
    error_message = "api_endpoint must be an https:// URL — EventBridge API destinations invoke HTTPS endpoints only."
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

variable "create_dlq" {
  type        = bool
  description = "Create an SQS dead-letter queue holding events EventBridge could not deliver. With this off, an event EventBridge gives up on is dropped and no copy of it exists anywhere."
  default     = true
}

variable "invocation_rate_limit_per_second" {
  type        = number
  description = "Ceiling on how many events per second EventBridge sends to the endpoint. AWS Health is low-volume, so the default leaves ample headroom while bounding what a broadened rule could aim at the endpoint. Events above the ceiling back up behind it and expire once they pass the target's maximum event age."
  default     = 10

  validation {
    condition     = var.invocation_rate_limit_per_second >= 1
    error_message = "invocation_rate_limit_per_second must be at least 1."
  }
}

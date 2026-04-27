variable "s3_deployment_bucket" {
  description = "S3 bucket ID for Lambda deployment artifacts"
  type        = string
}

variable "account_name" {
  description = "AWS account name for Slack notifications"
  type        = string
}

variable "regions" {
  description = "Comma-separated AWS regions for multi-region checks"
  type        = string
}

variable "slack_channel" {
  description = "Slack channel ID to post notifications to"
  type        = string
}

variable "slack_webhook_secret_name" {
  description = "Secrets Manager secret name containing WEBHOOK_URL and optionally SLACK_BOT_TOKEN keys"
  type        = string
  default     = "slack-webhook"
}

variable "anomaly_threshold" {
  description = "Cost anomaly threshold in USD"
  type        = string
  default     = "50"
}

variable "notification_emails" {
  description = "List of emails to notify on Lambda errors"
  type        = list(string)
  default     = []
}

variable "cloudtrail_enabled" {
  description = "Enable CloudTrail security event forwarding via EventBridge"
  type        = bool
  default     = false
}

variable "rds_monitoring_enabled" {
  description = "Enable RDS monitoring SNS topic and Lambda subscription"
  type        = bool
  default     = false
}

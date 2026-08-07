variable "name" {
  description = "Name prefix for all created resources (function, IAM role, event rules, SNS topics). Use a distinct value per module instance to avoid collisions."
  type        = string
  default     = "aws-events-to-slack"
}

variable "lambda_version" {
  description = "Version of the published aws-events-to-slack Lambda package to deploy. Resolves to the GitHub release asset aws-events-to-slack-<version>.zip from tag aws-events-to-slack-v<version>."
  type        = string
}

# name is ForceNew on all of these, and replacing an SNS topic silently drops
# subscribers the module does not own (AWS Chatbot, hand-added endpoints) while
# re-sending confirmation requests for the ones it does. Adopting this module over
# an existing deployment therefore needs a way to keep the names already in place.
variable "resource_names" {
  description = "Override individual resource names to match an existing deployment. Each unset field falls back to the var.name-prefixed default."
  type = object({
    daily_check_rule      = optional(string)
    health_rule           = optional(string)
    budgets_topic         = optional(string)
    db_monitoring_topic   = optional(string)
    anomaly_monitor       = optional(string)
    anomaly_subscription  = optional(string)
    cloudtrail_api_rule   = optional(string)
    cloudtrail_login_rule = optional(string)
  })
  default = {}
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

variable "slack_webhook_secret_arn" {
  description = "ARN of an externally-managed Secrets Manager secret holding WEBHOOK_URL and optionally SLACK_BOT_TOKEN keys"
  type        = string
}

variable "thresholds_url" {
  description = "Optional URL shown in budget alerts pointing to where alert thresholds are configured. When empty, the link is omitted."
  type        = string
  default     = ""
}

variable "health_event_categories" {
  description = "AWS Health event categories (eventTypeCategory) to forward. Empty list (default) forwards all categories. Valid values: issue, accountNotification, scheduledChange, investigation."
  type        = list(string)
  default     = []
}

variable "create_account_global_resources" {
  description = "Create account-global resources (daily scheduled check, budget/cost-anomaly SNS, Cost Explorer anomaly monitor). Set false on secondary-region instances that should only capture regional EventBridge events."
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log group retention in days for the Lambda"
  type        = number
  default     = 30
}

variable "timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 300
}

variable "access_key_warning_days" {
  description = "Warn when IAM access keys are older than this many days"
  type        = number
  default     = 365
}

variable "daily_check_schedule" {
  description = "EventBridge schedule expression for the daily maintenance/EOL/hygiene check"
  type        = string
  default     = "cron(0 9 * * ? *)"
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

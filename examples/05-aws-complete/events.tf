# Forward AWS events, maintenance alerts, and budget notifications to Slack.
# The Lambda package is pulled from this repo's GitHub release at apply time —
# no deployment bucket and no vendored source are required.
module "aws_events_to_slack" {
  source = "../../modules/aws-events-to-slack"

  lambda_version         = "1.0.0"
  account_name           = var.name_prefix
  regions                = var.region
  slack_channel          = var.slack_channel
  notification_emails    = var.notification_emails
  cloudtrail_enabled     = true
  rds_monitoring_enabled = true

  # Empty list forwards all AWS Health categories; listed here for illustration.
  health_event_categories = ["issue", "accountNotification", "scheduledChange", "investigation"]
}

# AWS Health delivers events for global services (IAM, CloudFront, Route 53, ...)
# to us-east-1, while regional events arrive in their own region. Deploy a second,
# Health-only instance via the us-east-1 provider to capture the global ones.
# create_account_global_resources = false keeps the account-wide budget/anomaly/
# daily-check resources on the primary instance only.
# Note: the slack-webhook Secrets Manager secret must also exist in us-east-1.
module "aws_events_to_slack_global" {
  source = "../../modules/aws-events-to-slack"

  providers = {
    aws = aws.virginia
  }

  name                            = "${var.name_prefix}-aws-events-global"
  lambda_version                  = "1.0.0"
  account_name                    = var.name_prefix
  regions                         = var.region
  slack_channel                   = var.slack_channel
  create_account_global_resources = false

  health_event_categories = ["issue", "accountNotification", "scheduledChange", "investigation"]
}

# Forward AWS events, maintenance alerts, and budget notifications to Slack.
# The Lambda package is pulled from this repo's GitHub release at apply time —
# no deployment bucket and no vendored source are required.
module "aws_events_to_slack" {
  source = "../../modules/aws-events-to-slack"

  lambda_version           = "1.0.0"
  account_name             = var.name_prefix
  regions                  = var.region
  slack_channel            = var.slack_channel
  slack_webhook_secret_arn = aws_secretsmanager_secret_version.slack_webhook.arn
  notification_emails      = var.notification_emails
  cloudtrail_enabled       = true
  rds_monitoring_enabled   = true

  # Empty list forwards all AWS Health categories; listed here for illustration.
  health_event_categories = ["issue", "accountNotification", "scheduledChange", "investigation"]
}

# The Slack webhook secret lives outside the module. This example creates one with a
# stub URL; replace the value with a real incoming-webhook URL before relying on it.
resource "aws_secretsmanager_secret" "slack_webhook" {
  #checkov:skip=CKV_AWS_149:Stub webhook config for the example; default AWS-managed key is sufficient
  #checkov:skip=CKV2_AWS_57:Slack webhook URL is a static credential, rotation is not applicable
  name = "${var.name_prefix}-slack-webhook"
}

resource "aws_secretsmanager_secret_version" "slack_webhook" {
  secret_id     = aws_secretsmanager_secret.slack_webhook.id
  secret_string = jsonencode({ WEBHOOK_URL = "https://hooks.slack.com/services/REPLACE-WITH-REAL-SLACK-WEBHOOK" })
}

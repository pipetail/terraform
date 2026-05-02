data "aws_caller_identity" "current" {}

locals {
  function_name = "aws-events-to-slack"
  cloudtrail_event_names = [
    "DeleteTrail",
    "StopLogging",
    "UpdateTrail",
    "CreateUser",
    "DeleteUser",
    "CreateRole",
    "DeleteRole",
    "CreateAccessKey",
    "DeleteAccessKey",
    "AttachUserPolicy",
    "AttachRolePolicy",
    "PutBucketPolicy",
    "AuthorizeSecurityGroupIngress",
    "StopInstances",
    "TerminateInstances",
  ]
}

data "aws_secretsmanager_secret" "slack_webhook" {
  name = var.slack_webhook_secret_name
}

data "aws_secretsmanager_secret_version" "slack_webhook" {
  secret_id = data.aws_secretsmanager_secret.slack_webhook.id
}

data "archive_file" "lambda_code" {
  type        = "zip"
  source_dir  = "${path.root}/../src/aws-events-to-slack"
  output_path = "${path.root}/../.terraform/tmp/aws-events-to-slack.zip"
}

resource "aws_s3_object" "lambda_code" {
  bucket = var.s3_deployment_bucket
  key    = "aws-events-to-slack.zip"
  source = data.archive_file.lambda_code.output_path
  etag   = data.archive_file.lambda_code.output_md5

  lifecycle {
    ignore_changes = [etag, source]
  }
}

module "lambda" {
  #checkov:skip=CKV_TF_1: Using registry versioning instead of commit hash
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.7.0"

  function_name = local.function_name
  description   = "Forward AWS events, maintenance alerts, and budget notifications to Slack"
  handler       = "index.handler"
  runtime       = "nodejs22.x"
  architectures = ["arm64"]
  timeout       = 300

  create_package = false
  s3_existing_package = {
    bucket = var.s3_deployment_bucket
    key    = "aws-events-to-slack.zip"
  }

  environment_variables = {
    SLACK_WEBHOOK_URL         = jsondecode(data.aws_secretsmanager_secret_version.slack_webhook.secret_string)["WEBHOOK_URL"]
    SLACK_BOT_TOKEN           = try(jsondecode(data.aws_secretsmanager_secret_version.slack_webhook.secret_string)["SLACK_BOT_TOKEN"], "")
    SLACK_CHANNEL             = var.slack_channel
    AWS_ACCOUNT_NAME          = var.account_name
    AWS_REGIONS               = var.regions
    ACCESS_KEY_WARNING_DAYS   = "365"
    CLOUDTRAIL_IGNORED_EVENTS = ""
  }

  attach_policy_json = true
  policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rds:DescribePendingMaintenanceActions",
          "rds:DescribeDBClusters",
          "elasticache:DescribeUpdateActions",
          "elasticache:DescribeCacheClusters",
          "elasticache:DescribeReplicationGroups",
          "acm:ListCertificates",
          "eks:ListClusters",
          "eks:DescribeCluster",
          "savingsplans:DescribeSavingsPlans",
          "iam:ListUsers",
          "iam:ListAccessKeys",
          "ec2:DescribeVolumes",
          "ec2:DescribeSnapshots",
          "ec2:DescribeImages",
        ]
        Resource = "*"
      }
    ]
  })

  depends_on = [aws_s3_object.lambda_code]
}

resource "aws_cloudwatch_event_rule" "daily_check" {
  name                = "aws-events-daily-check"
  description         = "Daily check for pending maintenance, EOL warnings, and resource hygiene"
  schedule_expression = "cron(0 9 * * ? *)"
}

resource "aws_cloudwatch_event_target" "daily_check" {
  rule = aws_cloudwatch_event_rule.daily_check.name
  arn  = module.lambda.lambda_function_arn
}

resource "aws_lambda_permission" "eventbridge_daily_check" {
  action        = "lambda:InvokeFunction"
  function_name = module.lambda.lambda_function_name
  principal     = "events.amazonaws.com"
  statement_id  = "AllowDailyCheckEventBridge"
  source_arn    = aws_cloudwatch_event_rule.daily_check.arn
}

resource "aws_cloudwatch_event_rule" "health_events" {
  name        = "aws-health-events"
  description = "Capture AWS Health events"

  event_pattern = jsonencode({
    source = ["aws.health"]
  })
}

resource "aws_cloudwatch_event_target" "health_events" {
  rule = aws_cloudwatch_event_rule.health_events.name
  arn  = module.lambda.lambda_function_arn
}

resource "aws_lambda_permission" "eventbridge_health" {
  action        = "lambda:InvokeFunction"
  function_name = module.lambda.lambda_function_name
  principal     = "events.amazonaws.com"
  statement_id  = "AllowHealthEventBridge"
  source_arn    = aws_cloudwatch_event_rule.health_events.arn
}

resource "aws_sns_topic" "budgets" {
  #checkov:skip=CKV_AWS_26:SNS encryption not required for budget alerts
  name = "budgets"
}

resource "aws_sns_topic_policy" "budgets" {
  arn = aws_sns_topic.budgets.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowBudgetsPublish"
        Effect = "Allow"
        Principal = {
          Service = "budgets.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.budgets.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid    = "AllowCostAnomalyPublish"
        Effect = "Allow"
        Principal = {
          Service = "costalerts.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.budgets.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

resource "aws_ce_anomaly_monitor" "cost" {
  name              = "cost-anomaly-monitor"
  monitor_type      = "DIMENSIONAL"
  monitor_dimension = "SERVICE"
}

resource "aws_ce_anomaly_subscription" "cost" {
  name = "cost-anomaly-subscription"

  monitor_arn_list = [aws_ce_anomaly_monitor.cost.arn]

  frequency = "IMMEDIATE"

  threshold_expression {
    dimension {
      key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
      values        = [var.anomaly_threshold]
      match_options = ["GREATER_THAN_OR_EQUAL"]
    }
  }

  subscriber {
    type    = "SNS"
    address = aws_sns_topic.budgets.arn
  }
}

resource "aws_sns_topic_subscription" "budget_alerts_to_lambda" {
  topic_arn = aws_sns_topic.budgets.arn
  protocol  = "lambda"
  endpoint  = module.lambda.lambda_function_arn
}

resource "aws_lambda_permission" "sns_budget_alerts" {
  action        = "lambda:InvokeFunction"
  function_name = module.lambda.lambda_function_name
  principal     = "sns.amazonaws.com"
  statement_id  = "AllowBudgetAlertsSNS"
  source_arn    = aws_sns_topic.budgets.arn
}

resource "aws_sns_topic" "lambda_alerts" {
  #checkov:skip=CKV_AWS_26:KMS encryption breaks SNS-to-email delivery
  name = "${local.function_name}-error-alerts"
}

resource "aws_sns_topic_subscription" "lambda_alerts_email" {
  for_each  = toset(var.notification_emails)
  topic_arn = aws_sns_topic.lambda_alerts.arn
  protocol  = "email"
  endpoint  = each.value
}

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${local.function_name}-errors"
  alarm_description   = "Fires when ${local.function_name} Lambda has any errors in a 24h period"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  statistic           = "Sum"
  period              = 86400
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  dimensions = {
    FunctionName = local.function_name
  }
  alarm_actions = [aws_sns_topic.lambda_alerts.arn]
}

resource "aws_sns_topic" "db_monitoring" {
  #checkov:skip=CKV_AWS_26:KMS encryption not required for RDS event notifications
  count = var.rds_monitoring_enabled ? 1 : 0
  name  = "db-monitoring"
}

resource "aws_sns_topic_subscription" "db_monitoring_to_lambda" {
  count     = var.rds_monitoring_enabled ? 1 : 0
  topic_arn = aws_sns_topic.db_monitoring[0].arn
  protocol  = "lambda"
  endpoint  = module.lambda.lambda_function_arn
}

resource "aws_lambda_permission" "sns_db_monitoring" {
  count         = var.rds_monitoring_enabled ? 1 : 0
  action        = "lambda:InvokeFunction"
  function_name = module.lambda.lambda_function_name
  principal     = "sns.amazonaws.com"
  statement_id  = "AllowDBMonitoringSNS"
  source_arn    = aws_sns_topic.db_monitoring[0].arn
}

resource "aws_cloudwatch_event_rule" "cloudtrail_api_calls" {
  count       = var.cloudtrail_enabled ? 1 : 0
  name        = "cloudtrail-security-api-calls"
  description = "Capture security-relevant CloudTrail API calls"

  event_pattern = jsonencode({
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventName       = local.cloudtrail_event_names
      sourceIPAddress = [{ "anything-but" = "autoscaling.amazonaws.com" }]
    }
  })
}

resource "aws_cloudwatch_event_target" "cloudtrail_api_calls" {
  count = var.cloudtrail_enabled ? 1 : 0
  rule  = aws_cloudwatch_event_rule.cloudtrail_api_calls[0].name
  arn   = module.lambda.lambda_function_arn
}

resource "aws_lambda_permission" "eventbridge_cloudtrail_api" {
  count         = var.cloudtrail_enabled ? 1 : 0
  action        = "lambda:InvokeFunction"
  function_name = module.lambda.lambda_function_name
  principal     = "events.amazonaws.com"
  statement_id  = "AllowCloudTrailApiEventBridge"
  source_arn    = aws_cloudwatch_event_rule.cloudtrail_api_calls[0].arn
}

resource "aws_cloudwatch_event_rule" "cloudtrail_console_login" {
  count       = var.cloudtrail_enabled ? 1 : 0
  name        = "cloudtrail-console-login"
  description = "Capture AWS Console login events"

  event_pattern = jsonencode({
    detail-type = ["AWS Console Sign In via CloudTrail"]
    detail = {
      eventName = ["ConsoleLogin"]
    }
  })
}

resource "aws_cloudwatch_event_target" "cloudtrail_console_login" {
  count = var.cloudtrail_enabled ? 1 : 0
  rule  = aws_cloudwatch_event_rule.cloudtrail_console_login[0].name
  arn   = module.lambda.lambda_function_arn
}

resource "aws_lambda_permission" "eventbridge_cloudtrail_login" {
  count         = var.cloudtrail_enabled ? 1 : 0
  action        = "lambda:InvokeFunction"
  function_name = module.lambda.lambda_function_name
  principal     = "events.amazonaws.com"
  statement_id  = "AllowCloudTrailLoginEventBridge"
  source_arn    = aws_cloudwatch_event_rule.cloudtrail_console_login[0].arn
}

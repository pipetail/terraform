data "aws_caller_identity" "current" {}

locals {
  name          = var.name
  create_global = var.create_account_global_resources
  release_tag   = "aws-events-to-slack-v${var.lambda_version}"
  zip_url       = "https://github.com/pipetail/terraform/releases/download/${local.release_tag}/aws-events-to-slack-${var.lambda_version}.zip"
  zip_path      = "${path.module}/.artifacts/aws-events-to-slack-${var.lambda_version}.zip"
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

data "aws_secretsmanager_secret_version" "slack_webhook" {
  secret_id = var.slack_webhook_secret_arn
}

# Fetch the published Lambda package from the GitHub release, keyed on version so
# it is re-downloaded only when var.lambda_version changes.
resource "null_resource" "lambda_package" {
  triggers = {
    version = var.lambda_version
  }

  provisioner "local-exec" {
    command = "mkdir -p '${dirname(local.zip_path)}' && curl -fsSL -o '${local.zip_path}' '${local.zip_url}'"
  }
}

# The release also publishes the base64-encoded SHA256 of the zip. Reading it over
# HTTP gives source_code_hash a real value at plan time, so the function updates on
# a version bump without needing the zip present on disk during plan.
data "http" "lambda_package_hash" {
  url = "${local.zip_url}.b64sha256"
}

resource "aws_iam_role" "lambda" {
  name = local.name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Action    = "sts:AssumeRole"
        Principal = { Service = "lambda.amazonaws.com" }
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda" {
  #checkov:skip=CKV_AWS_355:Read-only Describe/List actions span multiple services and are not resource-scopable
  name = "${local.name}-policy"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Logs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = "${aws_cloudwatch_log_group.lambda.arn}:*"
      },
      {
        Sid    = "ReadOnlyChecks"
        Effect = "Allow"
        Action = [
          "rds:DescribePendingMaintenanceActions",
          "rds:DescribeDBClusters",
          "elasticache:DescribeUpdateActions",
          "elasticache:DescribeCacheClusters",
          "elasticache:DescribeReplicationGroups",
          "acm:ListCertificates",
          "acm:DescribeCertificate",
          "eks:ListClusters",
          "eks:DescribeCluster",
          "savingsplans:DescribeSavingsPlans",
          "iam:ListUsers",
          "iam:ListAccessKeys",
          "ec2:DescribeVolumes",
          "ec2:DescribeSnapshots",
          "ec2:DescribeImages",
          "ec2:DescribeInstances",
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "lambda" {
  #checkov:skip=CKV_AWS_158:CloudWatch log group encryption with CMK not required for operational notifications
  #checkov:skip=CKV_AWS_338:Retention is configured via var.log_retention_days; 1-year minimum not required for operational notifications
  name              = "/aws/lambda/${local.name}"
  retention_in_days = var.log_retention_days
}

resource "aws_lambda_function" "this" {
  #checkov:skip=CKV_AWS_115:Reserved concurrency not required for low-volume event forwarding
  #checkov:skip=CKV_AWS_116:DLQ not required; failures alarm via CloudWatch and SNS
  #checkov:skip=CKV_AWS_117:VPC access not required; the function only calls public AWS APIs
  #checkov:skip=CKV_AWS_50:X-Ray tracing not required for this notification utility function
  #checkov:skip=CKV_AWS_173:Environment variables contain no secrets beyond a Slack token sourced from Secrets Manager
  #checkov:skip=CKV_AWS_272:Code signing not required for this internal utility function
  function_name = local.name
  description   = "Forward AWS events, maintenance alerts, and budget notifications to Slack"
  role          = aws_iam_role.lambda.arn
  handler       = "index.handler"
  runtime       = "nodejs22.x"
  architectures = ["arm64"]
  timeout       = var.timeout

  filename         = local.zip_path
  source_code_hash = chomp(data.http.lambda_package_hash.response_body)

  environment {
    variables = {
      SLACK_WEBHOOK_URL         = jsondecode(data.aws_secretsmanager_secret_version.slack_webhook.secret_string)["WEBHOOK_URL"]
      SLACK_BOT_TOKEN           = try(jsondecode(data.aws_secretsmanager_secret_version.slack_webhook.secret_string)["SLACK_BOT_TOKEN"], "")
      SLACK_CHANNEL             = var.slack_channel
      AWS_ACCOUNT_NAME          = var.account_name
      AWS_REGIONS               = var.regions
      ACCESS_KEY_WARNING_DAYS   = tostring(var.access_key_warning_days)
      CLOUDTRAIL_IGNORED_EVENTS = ""
      THRESHOLDS_URL            = var.thresholds_url
    }
  }

  # Marker tags the pipetail.cloud portal reads (Lambda ListTags) to identify this install and
  # surface its version + enabled features on the Alerts pillar, without enumerating the module's
  # EventBridge rules / SNS topics per region.
  tags = {
    Module            = "aws-events-to-slack"
    ModuleVersion     = var.lambda_version
    FeatureCloudtrail = tostring(var.cloudtrail_enabled)
    FeatureRds        = tostring(var.rds_monitoring_enabled)
    FeatureGlobal     = tostring(var.create_account_global_resources)
  }

  depends_on = [
    null_resource.lambda_package,
    aws_cloudwatch_log_group.lambda,
  ]
}

resource "aws_cloudwatch_event_rule" "daily_check" {
  count               = local.create_global ? 1 : 0
  name                = "${local.name}-daily-check"
  description         = "Daily check for pending maintenance, EOL warnings, and resource hygiene"
  schedule_expression = var.daily_check_schedule
}

resource "aws_cloudwatch_event_target" "daily_check" {
  count = local.create_global ? 1 : 0
  rule  = aws_cloudwatch_event_rule.daily_check[0].name
  arn   = aws_lambda_function.this.arn
}

resource "aws_lambda_permission" "eventbridge_daily_check" {
  count         = local.create_global ? 1 : 0
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "events.amazonaws.com"
  statement_id  = "AllowDailyCheckEventBridge"
  source_arn    = aws_cloudwatch_event_rule.daily_check[0].arn
}

resource "aws_cloudwatch_event_rule" "health_events" {
  name        = "${local.name}-health"
  description = "Capture AWS Health events"

  event_pattern = jsonencode(merge(
    {
      source        = ["aws.health"]
      "detail-type" = ["AWS Health Event"]
    },
    length(var.health_event_categories) > 0 ? {
      detail = { eventTypeCategory = var.health_event_categories }
    } : {}
  ))
}

resource "aws_cloudwatch_event_target" "health_events" {
  rule = aws_cloudwatch_event_rule.health_events.name
  arn  = aws_lambda_function.this.arn
}

resource "aws_lambda_permission" "eventbridge_health" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "events.amazonaws.com"
  statement_id  = "AllowHealthEventBridge"
  source_arn    = aws_cloudwatch_event_rule.health_events.arn
}

resource "aws_sns_topic" "budgets" {
  #checkov:skip=CKV_AWS_26:SNS encryption not required for budget alerts
  count = local.create_global ? 1 : 0
  name  = "${local.name}-budgets"
}

resource "aws_sns_topic_policy" "budgets" {
  count = local.create_global ? 1 : 0
  arn   = aws_sns_topic.budgets[0].arn

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
        Resource = aws_sns_topic.budgets[0].arn
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
        Resource = aws_sns_topic.budgets[0].arn
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
  count             = local.create_global ? 1 : 0
  name              = "${local.name}-cost-anomaly"
  monitor_type      = "DIMENSIONAL"
  monitor_dimension = "SERVICE"
}

resource "aws_ce_anomaly_subscription" "cost" {
  count = local.create_global ? 1 : 0
  name  = "${local.name}-cost-anomaly"

  monitor_arn_list = [aws_ce_anomaly_monitor.cost[0].arn]

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
    address = aws_sns_topic.budgets[0].arn
  }
}

resource "aws_sns_topic_subscription" "budget_alerts_to_lambda" {
  count     = local.create_global ? 1 : 0
  topic_arn = aws_sns_topic.budgets[0].arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.this.arn
}

resource "aws_lambda_permission" "sns_budget_alerts" {
  count         = local.create_global ? 1 : 0
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "sns.amazonaws.com"
  statement_id  = "AllowBudgetAlertsSNS"
  source_arn    = aws_sns_topic.budgets[0].arn
}

resource "aws_sns_topic" "lambda_alerts" {
  #checkov:skip=CKV_AWS_26:KMS encryption breaks SNS-to-email delivery
  name = "${local.name}-error-alerts"
}

resource "aws_sns_topic_subscription" "lambda_alerts_email" {
  for_each  = toset(var.notification_emails)
  topic_arn = aws_sns_topic.lambda_alerts.arn
  protocol  = "email"
  endpoint  = each.value
}

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${local.name}-errors"
  alarm_description   = "Fires when ${local.name} Lambda has any errors in a 24h period"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  statistic           = "Sum"
  period              = 86400
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  dimensions = {
    FunctionName = aws_lambda_function.this.function_name
  }
  alarm_actions = [aws_sns_topic.lambda_alerts.arn]
}

resource "aws_sns_topic" "db_monitoring" {
  #checkov:skip=CKV_AWS_26:KMS encryption not required for RDS event notifications
  count = var.rds_monitoring_enabled ? 1 : 0
  name  = "${local.name}-db-monitoring"
}

resource "aws_sns_topic_subscription" "db_monitoring_to_lambda" {
  count     = var.rds_monitoring_enabled ? 1 : 0
  topic_arn = aws_sns_topic.db_monitoring[0].arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.this.arn
}

resource "aws_lambda_permission" "sns_db_monitoring" {
  count         = var.rds_monitoring_enabled ? 1 : 0
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "sns.amazonaws.com"
  statement_id  = "AllowDBMonitoringSNS"
  source_arn    = aws_sns_topic.db_monitoring[0].arn
}

resource "aws_cloudwatch_event_rule" "cloudtrail_api_calls" {
  count       = var.cloudtrail_enabled ? 1 : 0
  name        = "${local.name}-cloudtrail-api-calls"
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
  arn   = aws_lambda_function.this.arn
}

resource "aws_lambda_permission" "eventbridge_cloudtrail_api" {
  count         = var.cloudtrail_enabled ? 1 : 0
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "events.amazonaws.com"
  statement_id  = "AllowCloudTrailApiEventBridge"
  source_arn    = aws_cloudwatch_event_rule.cloudtrail_api_calls[0].arn
}

resource "aws_cloudwatch_event_rule" "cloudtrail_console_login" {
  count       = var.cloudtrail_enabled ? 1 : 0
  name        = "${local.name}-cloudtrail-console-login"
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
  arn   = aws_lambda_function.this.arn
}

resource "aws_lambda_permission" "eventbridge_cloudtrail_login" {
  count         = var.cloudtrail_enabled ? 1 : 0
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "events.amazonaws.com"
  statement_id  = "AllowCloudTrailLoginEventBridge"
  source_arn    = aws_cloudwatch_event_rule.cloudtrail_console_login[0].arn
}

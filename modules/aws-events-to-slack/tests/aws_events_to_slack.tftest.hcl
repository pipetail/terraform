# Every run is a plan: the local-exec provisioner on null_resource.lambda_package
# still runs under a mocked provider on apply, and would curl the GitHub release.
mock_provider "null" {}

mock_provider "http" {
  override_during = plan

  override_data {
    target = data.http.lambda_package_hash
    values = {
      response_body = "Ym9ndXMtYnV0LXN0YWJsZS1zaGEyNTYtb2YtdGhlLXppcA==\n"
      status_code   = 200
    }
  }
}

mock_provider "aws" {
  override_during = plan

  override_data {
    target = data.aws_caller_identity.current
    values = {
      account_id = "123456789012"
    }
  }

  override_data {
    target = data.aws_secretsmanager_secret_version.slack_webhook
    values = {
      secret_string = "{\"WEBHOOK_URL\":\"https://example.com/webhook\",\"ROTATED_URL\":\"https://example.com/rotated\",\"SLACK_BOT_TOKEN\":\"example-bot-token\"}"
    }
  }

  mock_resource "aws_lambda_function" {
    defaults = {
      arn = "arn:aws:lambda:eu-central-1:123456789012:function:aws-events-to-slack"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/aws-events-to-slack"
    }
  }

  mock_resource "aws_cloudwatch_log_group" {
    defaults = {
      arn = "arn:aws:logs:eu-central-1:123456789012:log-group:/aws/lambda/aws-events-to-slack"
    }
  }

  mock_resource "aws_cloudwatch_event_rule" {
    defaults = {
      arn = "arn:aws:events:eu-central-1:123456789012:rule/aws-events-to-slack"
    }
  }

  mock_resource "aws_sns_topic" {
    defaults = {
      arn = "arn:aws:sns:eu-central-1:123456789012:aws-events-to-slack"
    }
  }

  mock_resource "aws_ce_anomaly_monitor" {
    defaults = {
      arn = "arn:aws:ce::123456789012:anomalymonitor/00000000-0000-0000-0000-000000000000"
    }
  }
}

override_resource {
  target          = aws_sns_topic.budgets
  override_during = plan
  values = {
    arn = "arn:aws:sns:eu-central-1:123456789012:aws-events-to-slack-budgets"
  }
}

override_resource {
  target          = aws_sns_topic.db_monitoring
  override_during = plan
  values = {
    arn = "arn:aws:sns:eu-central-1:123456789012:aws-events-to-slack-db-monitoring"
  }
}

variables {
  lambda_version           = "1.2.3"
  account_name             = "example-account"
  regions                  = "eu-central-1"
  slack_channel            = "C0123456789"
  slack_webhook_secret_arn = "arn:aws:secretsmanager:eu-central-1:123456789012:secret:example-slack-AbCdEf"
}

run "deploys_the_pinned_release_package" {
  command = plan

  assert {
    condition     = data.http.lambda_package_hash.url == "https://github.com/pipetail/terraform/releases/download/aws-events-to-slack-v1.2.3/aws-events-to-slack-1.2.3.zip.b64sha256"
    error_message = "The package hash must be read from the release asset of lambda_version."
  }

  assert {
    condition     = aws_lambda_function.this.source_code_hash == "Ym9ndXMtYnV0LXN0YWJsZS1zaGEyNTYtb2YtdGhlLXppcA=="
    error_message = "source_code_hash must be the published hash with the trailing newline stripped, or every plan shows a diff."
  }

  assert {
    condition     = endswith(aws_lambda_function.this.filename, "/.artifacts/aws-events-to-slack-1.2.3.zip")
    error_message = "The function must deploy the zip downloaded for lambda_version."
  }

  assert {
    condition     = null_resource.lambda_package.triggers.version == "1.2.3"
    error_message = "The download must be keyed on lambda_version so a bump fetches the new package."
  }

  assert {
    condition     = aws_lambda_function.this.environment[0].variables.SLACK_WEBHOOK_URL == "https://example.com/webhook" && aws_lambda_function.this.environment[0].variables.SLACK_BOT_TOKEN == "example-bot-token"
    error_message = "The Slack credentials must come from the secret's WEBHOOK_URL and SLACK_BOT_TOKEN keys."
  }

  assert {
    condition     = aws_lambda_function.this.environment[0].variables.AWS_ACCOUNT_ID == "123456789012"
    error_message = "AWS_ACCOUNT_ID must be the deploying account. The Lambda runtime does not set it, and notifications without an account id in the payload show \"Unknown\"."
  }

  assert {
    condition     = aws_lambda_function.this.tags.ModuleVersion == "1.2.3" && aws_lambda_function.this.tags.FeatureGlobal == "true"
    error_message = "The marker tags the portal reads must report the deployed version and enabled features."
  }
}

run "lambda_role_is_read_only_outside_its_log_group" {
  command = plan

  assert {
    condition     = jsondecode(aws_iam_role.lambda.assume_role_policy).Statement[0].Principal == { Service = "lambda.amazonaws.com" }
    error_message = "Only Lambda may assume the function role."
  }

  assert {
    condition = alltrue([
      for s in jsondecode(aws_iam_role_policy.lambda.policy).Statement : s.Resource == "${aws_cloudwatch_log_group.lambda.arn}:*"
      if s.Resource != "*"
    ])
    error_message = "Log writes must be scoped to the function's own log group."
  }

  assert {
    condition = alltrue(flatten([
      for s in jsondecode(aws_iam_role_policy.lambda.policy).Statement : [
        for a in s.Action : can(regex("^(Describe|List)", split(":", a)[1]))
      ] if s.Resource == "*"
    ]))
    error_message = "Every action granted on Resource \"*\" must be a Describe or List call."
  }

  assert {
    condition = alltrue([
      for s in jsondecode(aws_sns_topic_policy.budgets[0].policy).Statement : s.Condition.StringEquals["aws:SourceAccount"] == "123456789012"
    ])
    error_message = "Budgets and Cost Anomaly Detection may publish only on behalf of this account."
  }
}

run "global_resources_by_default_and_health_feed_filter" {
  command = plan

  assert {
    condition = alltrue([
      length(aws_cloudwatch_event_rule.daily_check) == 1,
      length(aws_sns_topic.budgets) == 1,
      length(aws_ce_anomaly_monitor.cost) == 1,
      length(aws_ce_anomaly_subscription.cost) == 1,
    ])
    error_message = "The account-global resources must be created by default."
  }

  assert {
    condition     = length(aws_cloudwatch_event_rule.cloudtrail_api_calls) == 0 && length(aws_sns_topic.db_monitoring) == 0
    error_message = "CloudTrail and RDS forwarding must be off by default."
  }

  assert {
    condition     = jsondecode(aws_cloudwatch_event_rule.health_events.event_pattern) == { source = ["aws.health"], "detail-type" = ["AWS Health Event"] }
    error_message = "By default the health rule must match the standard AWS Health feed."
  }

  assert {
    condition     = output.sns_topic_arn == aws_sns_topic.budgets[0].arn && output.db_monitoring_sns_topic_arn == null
    error_message = "sns_topic_arn must expose the budgets topic and db_monitoring_sns_topic_arn must be null."
  }
}

run "secondary_region_instance_skips_global_resources" {
  command = plan

  variables {
    create_account_global_resources = false
    health_detail_types             = []
    health_event_categories         = ["issue", "scheduledChange"]
  }

  assert {
    condition = alltrue([
      length(aws_cloudwatch_event_rule.daily_check) == 0,
      length(aws_sns_topic.budgets) == 0,
      length(aws_ce_anomaly_monitor.cost) == 0,
      length(aws_lambda_permission.sns_budget_alerts) == 0,
    ])
    error_message = "create_account_global_resources = false must skip the daily check, budgets topic and anomaly monitor."
  }

  assert {
    condition     = output.sns_topic_arn == null
    error_message = "sns_topic_arn must be null without the budgets topic."
  }

  assert {
    condition     = jsondecode(aws_cloudwatch_event_rule.health_events.event_pattern) == { source = ["aws.health"], detail = { eventTypeCategory = ["issue", "scheduledChange"] } }
    error_message = "An empty health_detail_types must drop the detail-type condition and categories must filter eventTypeCategory."
  }
}

run "optional_sources_and_name_overrides" {
  command = plan

  variables {
    cloudtrail_enabled       = true
    rds_monitoring_enabled   = true
    slack_webhook_secret_key = "ROTATED_URL"
    resource_names = {
      budgets_topic = "legacy-budgets"
    }
  }

  assert {
    condition     = length(aws_cloudwatch_event_rule.cloudtrail_api_calls) == 1 && length(aws_cloudwatch_event_rule.cloudtrail_console_login) == 1
    error_message = "cloudtrail_enabled must create both CloudTrail rules."
  }

  assert {
    condition     = contains(jsondecode(aws_cloudwatch_event_rule.cloudtrail_api_calls[0].event_pattern).detail.eventName, "StopLogging")
    error_message = "The CloudTrail rule must catch attempts to stop logging."
  }

  assert {
    condition     = output.db_monitoring_sns_topic_arn == aws_sns_topic.db_monitoring[0].arn && length(aws_lambda_permission.sns_db_monitoring) == 1
    error_message = "rds_monitoring_enabled must create the topic and let it invoke the function."
  }

  assert {
    condition     = aws_sns_topic.budgets[0].name == "legacy-budgets" && aws_sns_topic.lambda_alerts.name == "aws-events-to-slack-error-alerts"
    error_message = "resource_names must override only the named resource and leave the others on the var.name prefix."
  }

  assert {
    condition     = aws_lambda_function.this.environment[0].variables.SLACK_WEBHOOK_URL == "https://example.com/rotated"
    error_message = "slack_webhook_secret_key must select which secret key holds the webhook URL."
  }
}

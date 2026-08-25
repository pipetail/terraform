# Forwards this account's AWS Health events to pipetail.cloud.
#
# The ingest key is deliberately not an input: any value Terraform passes to a connection is
# stored in plaintext in state and in saved plans. The connection is created with a placeholder
# and the real key is written directly to EventBridge with the set_key_command output. Terraform
# therefore cannot detect an unset, wrong, or rotated key; failed deliveries arriving in the
# dead-letter queue are the detection path.
#
# One instance covers exactly one Region: connections, API destinations and rules are Regional,
# and a rule can only target a destination in its own Region. Instantiate the module once per
# Region with that Region's provider.
#
# A Region-specific Health event is delivered in the Region it affects; events that are not
# Region-specific (IAM among them) are delivered only in us-east-1, so a us-east-1 instance is
# needed on top of the Regions holding resources. us-west-2 additionally receives a copy of every
# other Region's events, marked detail.backupEvent, and us-east-1 backs up us-west-2.
# https://docs.aws.amazon.com/health/latest/ug/choosing-a-region.html

locals {
  # Named in the connection and again in the set_key_command output. update-connection rewrites
  # both the header name and the value, so a drift between the two would move the key to a header
  # pipetail.cloud does not read.
  ingest_key_header = "X-Pipetail-Ingest-Key"

  # EventBridge requires an API key when the connection is created.
  ingest_key_placeholder = "REPLACE_ME"
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

resource "aws_cloudwatch_event_connection" "this" {
  name               = var.name
  description        = "API key for sending AWS Health events to pipetail.cloud"
  authorization_type = "API_KEY"

  auth_parameters {
    api_key {
      key   = local.ingest_key_header
      value = local.ingest_key_placeholder
    }
  }

  # The real key is written outside Terraform. Without this, every apply would push the
  # placeholder back over it and silently stop authenticating.
  lifecycle {
    ignore_changes = [auth_parameters]
  }
}

resource "aws_cloudwatch_event_api_destination" "this" {
  name                             = var.name
  description                      = "POST AWS Health events to pipetail.cloud"
  invocation_endpoint              = var.api_endpoint
  http_method                      = "POST"
  connection_arn                   = aws_cloudwatch_event_connection.this.arn
  invocation_rate_limit_per_second = var.invocation_rate_limit_per_second
}

resource "aws_cloudwatch_event_rule" "this" {
  name          = var.name
  description   = "Forward AWS Health events to pipetail.cloud"
  event_pattern = jsonencode({ source = ["aws.health"] })
}

resource "aws_iam_role" "invoke" {
  name_prefix = "${var.name}-"
  description = "Lets EventBridge invoke the pipetail.cloud AWS Health API destination"

  # The SourceArn/SourceAccount conditions stop any other principal in the account from passing
  # this role to a rule of its own and posting arbitrary payloads through the stored connection
  # credential (cross-service confused deputy).
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "events.amazonaws.com" }
        Action    = "sts:AssumeRole"
        Condition = {
          StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
          ArnLike      = { "aws:SourceArn" = aws_cloudwatch_event_rule.this.arn }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "invoke" {
  name = "invoke-api-destination"
  role = aws_iam_role.invoke.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "events:InvokeApiDestination"
        Resource = aws_cloudwatch_event_api_destination.this.arn
      }
    ]
  })
}

resource "aws_sqs_queue" "dlq" {
  count = var.create_dlq ? 1 : 0

  name = "${var.name}-dlq"

  # 14 days, the SQS maximum. Once EventBridge moves an event here it stops retrying, so this copy
  # is the only one left. Read the queue before the retention runs out.
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true
}

resource "aws_sqs_queue_policy" "dlq" {
  count = var.create_dlq ? 1 : 0

  queue_url = aws_sqs_queue.dlq[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "events.amazonaws.com" }
        Action    = "sqs:SendMessage"
        Resource  = aws_sqs_queue.dlq[0].arn
        Condition = {
          ArnEquals = { "aws:SourceArn" = aws_cloudwatch_event_rule.this.arn }
        }
      }
    ]
  })
}

resource "aws_cloudwatch_event_target" "this" {
  # No input transformer: pipetail.cloud reads the EventBridge envelope as AWS sends it.
  rule      = aws_cloudwatch_event_rule.this.name
  target_id = var.target_id
  arn       = aws_cloudwatch_event_api_destination.this.arn
  role_arn  = aws_iam_role.invoke.arn

  # EventBridge's default retries a failing delivery for 24 hours. An hour rides out a blip; past
  # that the event lands in the dead-letter queue while it is still current.
  retry_policy {
    maximum_event_age_in_seconds = 3600
  }

  dynamic "dead_letter_config" {
    for_each = var.create_dlq ? [1] : []

    content {
      arn = aws_sqs_queue.dlq[0].arn
    }
  }
}

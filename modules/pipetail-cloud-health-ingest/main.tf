# Forwards this account's AWS Health events to pipetail.cloud, replacing the EventBridge setup
# the portal otherwise documents clicking through the console.
#
# One instance covers exactly one Region: EventBridge connections, API destinations and rules are
# all Regional, and a rule can only target a destination in its own Region. Pass a provider per
# Region and instantiate the module once per Region.
#
# Which Regions to cover: a Region-specific event is delivered in the Region it affects, and an
# event that is not Region-specific (IAM among them) only in us-east-1 — so a us-east-1 instance
# is needed on top of the Regions holding resources, or those events never arrive. The same page
# describes backup delivery: an instance in us-west-2 also receives a copy of every other Region's
# events, marked detail.backupEvent, and us-east-1 backs up us-west-2.
# https://docs.aws.amazon.com/health/latest/ug/choosing-a-region.html

resource "aws_cloudwatch_event_connection" "this" {
  name               = var.name
  description        = "API key for sending AWS Health events to pipetail.cloud"
  authorization_type = "API_KEY"

  auth_parameters {
    api_key {
      key   = "X-Pipetail-Ingest-Key"
      value = var.ingest_key
    }
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

# The IAM role is the only global resource here, so it is built from a prefix and AWS appends a
# unique suffix — instantiating the module in several Regions with the same name would otherwise
# collide on it.
resource "aws_iam_role" "invoke" {
  name_prefix = "${var.name}-"
  description = "Lets EventBridge invoke the pipetail.cloud AWS Health API destination"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "events.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

# The trust above is unconditioned; this is what bounds the role — one destination, one action,
# no ability to reach anything else in the account.
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
  # is the only one left — read the queue before the retention runs out.
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
  target_id = "pipetail-cloud-ingest"
  arn       = aws_cloudwatch_event_api_destination.this.arn
  role_arn  = aws_iam_role.invoke.arn

  # EventBridge otherwise retries a failing delivery for 24 hours. An hour rides out a blip; past
  # that the event reaches the dead-letter queue, where it can be read, while it is still current.
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

mock_provider "aws" {
  override_data {
    target = data.aws_caller_identity.current
    values = {
      account_id = "123456789012"
    }
  }

  mock_resource "aws_cloudwatch_event_connection" {
    defaults = {
      arn = "arn:aws:events:eu-central-1:123456789012:connection/pipetail-cloud-health-ingest/00000000-0000-0000-0000-000000000000"
    }
  }

  mock_resource "aws_cloudwatch_event_api_destination" {
    defaults = {
      arn = "arn:aws:events:eu-central-1:123456789012:api-destination/pipetail-cloud-health-ingest/00000000-0000-0000-0000-000000000000"
    }
  }

  mock_resource "aws_cloudwatch_event_rule" {
    defaults = {
      arn = "arn:aws:events:eu-central-1:123456789012:rule/pipetail-cloud-health-ingest"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/pipetail-cloud-health-ingest-example"
    }
  }

  mock_resource "aws_sqs_queue" {
    defaults = {
      arn = "arn:aws:sqs:eu-central-1:123456789012:pipetail-cloud-health-ingest-dlq"
      id  = "https://sqs.eu-central-1.amazonaws.com/123456789012/pipetail-cloud-health-ingest-dlq"
      url = "https://sqs.eu-central-1.amazonaws.com/123456789012/pipetail-cloud-health-ingest-dlq"
    }
  }
}

run "forwards_health_events_through_a_scoped_role" {
  command = apply

  assert {
    condition     = jsondecode(aws_cloudwatch_event_rule.this.event_pattern) == { source = ["aws.health"] }
    error_message = "The rule must match AWS Health events only."
  }

  assert {
    condition     = aws_cloudwatch_event_target.this.arn == aws_cloudwatch_event_api_destination.this.arn && aws_cloudwatch_event_target.this.role_arn == aws_iam_role.invoke.arn
    error_message = "The rule must deliver to the API destination through the module's invoke role."
  }

  assert {
    condition     = aws_cloudwatch_event_target.this.retry_policy[0].maximum_event_age_in_seconds == 3600
    error_message = "Failed deliveries must stop retrying after an hour so they reach the dead-letter queue while still current."
  }

  assert {
    condition = jsondecode(aws_iam_role.invoke.assume_role_policy).Statement[0].Condition == {
      StringEquals = { "aws:SourceAccount" = "123456789012" }
      ArnLike      = { "aws:SourceArn" = aws_cloudwatch_event_rule.this.arn }
    }
    error_message = "The invoke role must be assumable only by this account's rule, or any principal could post through the stored credential."
  }

  assert {
    condition     = jsondecode(aws_iam_role.invoke.assume_role_policy).Statement[0].Principal == { Service = "events.amazonaws.com" }
    error_message = "Only EventBridge may assume the invoke role."
  }

  assert {
    condition = jsondecode(aws_iam_role_policy.invoke.policy).Statement == [{
      Effect   = "Allow"
      Action   = "events:InvokeApiDestination"
      Resource = aws_cloudwatch_event_api_destination.this.arn
    }]
    error_message = "The invoke role may only invoke this module's API destination."
  }
}

run "connection_carries_a_placeholder_not_the_key" {
  command = apply

  assert {
    condition     = aws_cloudwatch_event_connection.this.auth_parameters[0].api_key[0].value == "REPLACE_ME"
    error_message = "The ingest key must never reach Terraform state; the connection must carry the placeholder."
  }

  assert {
    condition     = aws_cloudwatch_event_connection.this.auth_parameters[0].api_key[0].key == "X-Pipetail-Ingest-Key"
    error_message = "The README snippet writes the key under this header name and pipetail.cloud reads it from there; change all three together."
  }

  assert {
    condition     = startswith(aws_cloudwatch_event_api_destination.this.invocation_endpoint, "https://") && aws_cloudwatch_event_api_destination.this.http_method == "POST"
    error_message = "Events must be POSTed to an https endpoint."
  }
}

run "dlq_is_encrypted_and_accepts_only_the_rule" {
  command = apply

  assert {
    condition     = aws_sqs_queue.dlq[0].sqs_managed_sse_enabled == true
    error_message = "The dead-letter queue holds event payloads and must be encrypted."
  }

  assert {
    condition     = aws_sqs_queue.dlq[0].message_retention_seconds == 1209600
    error_message = "The dead-letter queue must keep messages for the 14-day SQS maximum."
  }

  assert {
    condition = jsondecode(aws_sqs_queue_policy.dlq[0].policy).Statement == [{
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.dlq[0].arn
      Condition = { ArnEquals = { "aws:SourceArn" = aws_cloudwatch_event_rule.this.arn } }
    }]
    error_message = "Only this module's rule may send to the dead-letter queue."
  }

  assert {
    condition     = aws_cloudwatch_event_target.this.dead_letter_config[0].arn == aws_sqs_queue.dlq[0].arn
    error_message = "The target must send undeliverable events to the dead-letter queue."
  }

  assert {
    condition     = output.dlq_arn == aws_sqs_queue.dlq[0].arn && output.dlq_queue_url == aws_sqs_queue.dlq[0].id
    error_message = "dlq_arn and dlq_queue_url must expose the created queue."
  }
}

run "create_dlq_false_drops_the_queue" {
  command = apply

  variables {
    create_dlq = false
  }

  assert {
    condition     = length(aws_sqs_queue.dlq) == 0 && length(aws_sqs_queue_policy.dlq) == 0
    error_message = "create_dlq = false must not create the queue or its policy."
  }

  assert {
    condition     = length(aws_cloudwatch_event_target.this.dead_letter_config) == 0
    error_message = "Without a queue the target must carry no dead-letter config."
  }

  assert {
    condition     = output.dlq_arn == null && output.dlq_queue_url == null
    error_message = "The queue outputs must be null when no queue exists."
  }
}

run "rejects_a_plain_http_endpoint" {
  command = plan

  variables {
    api_endpoint = "http://example.com/ingest"
  }

  expect_failures = [var.api_endpoint]
}

run "rejects_a_name_too_long_for_the_role_prefix" {
  command = plan

  variables {
    name = "example-health-ingest-name-that-is-038"
  }

  expect_failures = [var.name]
}

run "rejects_a_target_id_with_spaces" {
  command = plan

  variables {
    target_id = "example target"
  }

  expect_failures = [var.target_id]
}

run "rejects_a_zero_rate_limit" {
  command = plan

  variables {
    invocation_rate_limit_per_second = 0
  }

  expect_failures = [var.invocation_rate_limit_per_second]
}

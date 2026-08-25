output "set_key_command" {
  description = "Run this once after apply, with the AWS Health ingest key generated in pipetail.cloud under Settings pasted in place of the placeholder. It writes the key straight to EventBridge, which is why the key never enters Terraform state. Rotating the key is the same command with a new value, and no apply is needed."
  value = format(
    "aws events update-connection --name %s --region %s --auth-parameters '%s'",
    aws_cloudwatch_event_connection.this.name,
    data.aws_region.current.name,
    jsonencode({
      ApiKeyAuthParameters = {
        ApiKeyName  = local.ingest_key_header
        ApiKeyValue = "PASTE_INGEST_KEY_HERE"
      }
    }),
  )
}

output "rule_arn" {
  description = "ARN of the EventBridge rule matching AWS Health events in this Region"
  value       = aws_cloudwatch_event_rule.this.arn
}

output "api_destination_arn" {
  description = "ARN of the API destination the rule delivers to"
  value       = aws_cloudwatch_event_api_destination.this.arn
}

output "dlq_arn" {
  description = "ARN of the dead-letter queue, or null when create_dlq is false"
  value       = one(aws_sqs_queue.dlq[*].arn)
}

output "dlq_queue_url" {
  description = "URL of the dead-letter queue to read undelivered events from, or null when create_dlq is false"
  value       = one(aws_sqs_queue.dlq[*].id)
}

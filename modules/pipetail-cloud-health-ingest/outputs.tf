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

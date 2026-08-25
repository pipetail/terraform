output "set_key_command" {
  description = "Run this snippet once after apply; it prompts for the AWS Health ingest key generated in pipetail.cloud under Settings with the input hidden. The key is written straight to EventBridge, which is why it never enters Terraform state, and it stays out of the process argv and shell history: the printf builtin writes it into a mktemp-owned payload file that a trap removes even on interruption. Rotating the key is the same snippet with the new value, and no apply is needed. Needs bash or zsh."
  value       = <<-EOT
    (
      set -e
      d="$(mktemp -d)"; trap 'rm -rf "$d"' EXIT
      printf 'Paste the AWS Health ingest key (input hidden): ' >&2
      IFS= read -rs key; printf '\n' >&2
      printf '{"Name":"%s","AuthParameters":{"ApiKeyAuthParameters":{"ApiKeyName":"%s","ApiKeyValue":"%s"}}}' '${aws_cloudwatch_event_connection.this.name}' '${local.ingest_key_header}' "$key" > "$d/connection.json"
      aws events update-connection --region ${data.aws_region.current.name} --cli-input-json "file://$d/connection.json"
    )
  EOT
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

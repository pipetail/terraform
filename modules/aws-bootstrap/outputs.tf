output "state_bucket" {
  description = "The state_bucket name"
  value       = local.state_bucket
}

output "dynamodb_table" {
  description = "The name of the dynamo db table"
  value       = aws_dynamodb_table.terraform_state_lock.id
}

output "state_bucket" {
  description = "The state_bucket name"
  value       = local.state_bucket
}

output "dynamodb_table" {
  description = "The name of the dynamo db table"
  value       = var.create_dynamodb_table ? aws_dynamodb_table.terraform_state_lock[0].id : null
}

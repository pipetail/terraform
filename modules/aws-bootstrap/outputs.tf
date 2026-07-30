output "state_bucket" {
  description = "The state_bucket name"
  value       = local.state_bucket
}

output "state_bucket_arn" {
  description = "ARN of the bucket storing the Terraform state files"
  value       = module.terraform_state.s3_bucket_arn
}

output "region" {
  description = "AWS region the state bucket lives in, for the backend block"
  value       = var.region
}

output "dynamodb_table" {
  description = "The name of the dynamo db table"
  value       = var.create_dynamodb_table ? aws_dynamodb_table.terraform_state_lock[0].id : null
}

output "log_bucket" {
  value       = try(module.state_logs[0].s3_bucket_id, null)
  description = "Name of the bucket receiving the state bucket's access logs, or null when access logging is off or points at an external bucket"
}

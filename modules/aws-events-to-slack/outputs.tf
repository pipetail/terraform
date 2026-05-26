output "sns_topic_arn" {
  description = "ARN of the SNS topic for budget alerts (null when account-global resources are disabled)"
  value       = var.create_account_global_resources ? aws_sns_topic.budgets[0].arn : null
}

output "db_monitoring_sns_topic_arn" {
  description = "ARN of the RDS monitoring SNS topic"
  value       = var.rds_monitoring_enabled ? aws_sns_topic.db_monitoring[0].arn : null
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.this.arn
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.this.function_name
}

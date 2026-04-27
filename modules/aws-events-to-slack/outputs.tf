output "sns_topic_arn" {
  description = "ARN of the SNS topic for budget alerts"
  value       = aws_sns_topic.budgets.arn
}

output "db_monitoring_sns_topic_arn" {
  description = "ARN of the RDS monitoring SNS topic"
  value       = var.rds_monitoring_enabled ? aws_sns_topic.db_monitoring[0].arn : null
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = module.lambda.lambda_function_arn
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = module.lambda.lambda_function_name
}

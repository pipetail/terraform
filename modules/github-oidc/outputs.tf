output "role_arn" {
  value       = aws_iam_role.github_actions.arn
  description = "Github Actions IAM Role ARN"
}

output "role_name" {
  value       = aws_iam_role.github_actions.name
  description = "Github Actions IAM Role ARN"
}

output "roles" {
  value       = aws_iam_role.github_actions
  description = "Github Actions IAM Role ARN"
}

output "oidc_provider_arn" {
  value       = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : null
  description = "OIDC Provider ARN"
}

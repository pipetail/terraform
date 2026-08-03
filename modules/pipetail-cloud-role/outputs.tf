output "role_arn" {
  description = "ARN of the created role — paste this into pipetail.cloud to complete the connection"
  value       = aws_iam_role.pipetail_cloud.arn
}

output "role_name" {
  description = "Name of the created role"
  value       = aws_iam_role.pipetail_cloud.name
}

resource "aws_cloudwatch_log_group" "command_execution" {
  #checkov:skip=CKV_AWS_338: Retention is configurable via variable, default is acceptable for example code
  name = "ecs-command-execution"

  retention_in_days = var.retention_in_days

  kms_key_id = aws_kms_key.main.arn
}

// Please note that these IAM permissions needs to be set at the ECS task role level (not at the ECS task execution role level).
// This is because the SSM core agent runs alongside your application in the same container. It’s the container itself that needs
// to be granted the IAM permission to perform those actions against other AWS services.
// https://aws.amazon.com/blogs/containers/new-using-amazon-ecs-exec-access-your-containers-fargate-ec2/
locals {
  #checkov:skip=CKV_AWS_356:ssmmessages actions do not support resource-level permissions
  allow_command_exec_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel",
        ]
        Resource = ["*"]
      },
      {
        // Split out from the ssmmessages actions, which genuinely cannot be
        // resource-scoped. kms:Decrypt can: ECS Exec only ever needs the key
        // named in the cluster's execute_command_configuration. On "*" a task
        // that got compromised could decrypt against any CMK whose policy
        // delegates to the account root, which is how the shared key covering
        // Aurora, flow logs and EKS secrets is written.
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = [aws_kms_key.main.arn]
      },
      {
        Effect   = "Allow"
        Action   = ["logs:DescribeLogGroups"]
        Resource = ["*"]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
        ]
        Resource = ["${aws_cloudwatch_log_group.command_execution.arn}:*"]
      },
    ]
  })
}

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
data "aws_iam_policy_document" "allow_command_exec" {
  #checkov:skip=CKV_AWS_111:We should review this TODO
  #checkov:skip=CKV_AWS_356:SSM and logs actions require wildcard resources
  statement {
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel",
      "kms:Decrypt"
    ]
    resources = ["*"]
  }

  statement {
    actions = [
      "logs:DescribeLogGroups",
    ]
    resources = ["*"]
  }

  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]
    resources = ["${aws_cloudwatch_log_group.command_execution.arn}:*"]
  }
}

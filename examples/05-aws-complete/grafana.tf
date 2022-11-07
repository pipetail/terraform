resource "aws_ecs_cluster" "grafana" {
  name = "grafana"

  configuration {
    execute_command_configuration {
      kms_key_id = aws_kms_key.main.arn
      logging    = "OVERRIDE"

      log_configuration {
        cloud_watch_encryption_enabled = true
        cloud_watch_log_group_name     = aws_cloudwatch_log_group.command_execution.name
      }
    }
  }

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name      = "grafana"
    ManagedBy = "Terraform"
  }
}

resource "aws_ecr_repository" "grafana" {
  #checkov:skip=CKV_AWS_136:We don't use KMS to encrypt images now TODO: we should
  #checkov:skip=CKV_AWS_51:We don't enforce tag immutability here since we reuse tags often, not ideal but ok here
  name = "grafana"

  image_scanning_configuration {
    scan_on_push = true
  }
}

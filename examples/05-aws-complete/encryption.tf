data "aws_partition" "current" {}

resource "aws_kms_key" "main" {
  #checkov:skip=CKV_AWS_109: The asterisk ("*") identifies the KMS key to which the key policy is attached. https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-overview.html
  #checkov:skip=CKV_AWS_111: The asterisk ("*") identifies the KMS key to which the key policy is attached. https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-overview.html
  #checkov:skip=CKV_AWS_356: The asterisk ("*") identifies the KMS key to which the key policy is attached. https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-overview.html
  description             = "Shared KMS key"
  deletion_window_in_days = 10
  key_usage               = "ENCRYPT_DECRYPT"
  enable_key_rotation     = true
  is_enabled              = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Allow key administration"
        Effect = "Allow"
        Principal = {
          AWS = sort([
            data.aws_iam_role.github_actions.arn,
            aws_iam_role.eks_access_administrator.arn,
          ])
        }
        Action = [
          "kms:Describe*",
          "kms:Enable*",
          "kms:List*",
          "kms:Put*",
          "kms:Update*",
          "kms:Revoke*",
          "kms:Disable*",
          "kms:Get*",
          "kms:Delete*",
          "kms:TagResource",
          "kms:UntagResource",
          "kms:ScheduleKeyDeletion",
          "kms:CancelKeyDeletion",
          "kms:RotateKeyOnDemand",
        ]
        Resource = ["*"]
      },
      {
        Sid    = "Allow key use"
        Effect = "Allow"
        Principal = {
          AWS = data.aws_iam_role.github_actions.arn
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
        ]
        Resource = ["*"]
      },
      {
        Sid    = "Allow grants for AWS resources"
        Effect = "Allow"
        Principal = {
          AWS = data.aws_iam_role.github_actions.arn
        }
        Action = [
          "kms:CreateGrant",
          "kms:ListGrants",
          "kms:RevokeGrant",
        ]
        Resource = ["*"]
        Condition = {
          Bool = {
            "kms:GrantIsForAWSResource" = "true"
          }
        }
      },
      {
        Sid    = "Allow Loki to decrypt ECS Exec data"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.loki_ecs_task.arn
        }
        Action   = ["kms:Decrypt"]
        Resource = ["*"]
      },
      {
        Sid    = "Allow cloudwatch log group encryption"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*",
        ]
        Resource = ["*"]
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = sort([
              "arn:${data.aws_partition.current.partition}:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/vpc-flow-logs/*",
              "arn:${data.aws_partition.current.partition}:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:ecs-command-execution",
            ])
          }
        }
      },
    ]
  })
}

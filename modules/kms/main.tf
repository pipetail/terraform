locals {
  kms_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Allow everything in this AWS account to use this KMS key"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow cloudwatch log group encryption"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow cloudtrail encryption"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_kms_key" "main" {
  #checkov:skip=CKV_AWS_109:The asterisk identifies the KMS key to which the key policy is attached
  #checkov:skip=CKV_AWS_111:The asterisk identifies the KMS key to which the key policy is attached
  #checkov:skip=CKV_AWS_356:The asterisk identifies the KMS key to which the key policy is attached
  description             = "Shared KMS key"
  deletion_window_in_days = var.deletion_window_in_days
  key_usage               = "ENCRYPT_DECRYPT"
  enable_key_rotation     = var.key_rotation_enabled
  is_enabled              = true

  policy = local.kms_policy
}

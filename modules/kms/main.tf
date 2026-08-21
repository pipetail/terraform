locals {
  kms_policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid    = "Allow key administration"
          Effect = "Allow"
          Principal = {
            AWS = sort(tolist(var.key_administrator_arns))
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
          Resource = "*"
        },
      ],
      slice(
        [
          {
            Sid    = "Allow key use"
            Effect = "Allow"
            Principal = {
              AWS = sort(tolist(var.key_user_arns))
            }
            Action = [
              "kms:Encrypt",
              "kms:Decrypt",
              "kms:ReEncrypt*",
              "kms:GenerateDataKey*",
              "kms:DescribeKey",
            ]
            Resource = "*"
          },
          {
            Sid    = "Allow grants for AWS resources"
            Effect = "Allow"
            Principal = {
              AWS = sort(tolist(var.key_user_arns))
            }
            Action = [
              "kms:CreateGrant",
              "kms:ListGrants",
              "kms:RevokeGrant",
            ]
            Resource = "*"
            Condition = {
              Bool = {
                "kms:GrantIsForAWSResource" = "true"
              }
            }
          },
        ],
        0,
        length(var.key_user_arns) > 0 ? 2 : 0,
      ),
      [
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
    )
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

  // Replacing this key is unrecoverable: anything already encrypted under it —
  // RDS storage, EBS volumes, EKS secrets, log groups — becomes permanently
  // unreadable once the deletion window elapses. A stray -target, a module
  // refactor without a moved block, or a provider upgrade that forces
  // replacement would otherwise queue that destroy inside a large plan.
  lifecycle {
    prevent_destroy = true
  }
}

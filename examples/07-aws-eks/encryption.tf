resource "aws_kms_key" "eks" {
  #checkov:skip=CKV_AWS_109: The asterisk ("*") identifies the KMS key to which the key policy is attached. https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-overview.html
  #checkov:skip=CKV_AWS_111: The asterisk ("*") identifies the KMS key to which the key policy is attached. https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-overview.html
  #checkov:skip=CKV_AWS_356: The asterisk ("*") identifies the KMS key to which the key policy is attached. https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-overview.html
  description = "EKS secrets encryption for the e2e example"
  // The minimum AWS allows. Every cycle leaves one key pending deletion.
  deletion_window_in_days = 7
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
          AWS = data.aws_iam_role.github_actions.arn
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
    ]
  })
}

data "aws_iam_role" "github_actions" {
  name = "github_actions_terraform"
}

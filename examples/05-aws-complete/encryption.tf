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
        Sid    = "Allow everything in this AWS account to use this KMS key"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = ["kms:*"]
        Resource = ["*"]
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
          "kms:Describe*",
        ]
        Resource = ["*"]
      },
    ]
  })
}

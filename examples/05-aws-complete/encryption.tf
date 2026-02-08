data "aws_iam_policy_document" "allow_main_kms" {
  #checkov:skip=CKV_AWS_109: The asterisk ("*") identifies the KMS key to which the key policy is attached. https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-overview.html
  #checkov:skip=CKV_AWS_111: The asterisk ("*") identifies the KMS key to which the key policy is attached. https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-overview.html
  #checkov:skip=CKV_AWS_356: The asterisk ("*") identifies the KMS key to which the key policy is attached. https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-overview.html

  statement {
    actions = [
      "kms:*"
    ]
    effect = "Allow"
    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root",
      ]
    }
    resources = ["*"]
    sid       = "Allow everything in this AWS account to use this KMS key"
  }

  statement {
    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*"
    ]
    principals {
      type = "Service"
      identifiers = [
        "logs.${var.region}.amazonaws.com"
      ]
    }
    resources = ["*"]
    sid       = "Allow cloudwatch log group encryption"
  }
}

resource "aws_kms_key" "main" {
  description             = "Shared KMS key"
  deletion_window_in_days = 10
  key_usage               = "ENCRYPT_DECRYPT"
  enable_key_rotation     = true
  is_enabled              = true

  policy = data.aws_iam_policy_document.allow_main_kms.json
}

resource "aws_kms_alias" "secrets_encryption" {
  target_key_id = var.secrets_encryption_kms_key_arn
  name          = "alias/eks_${var.name}_encryption"
}

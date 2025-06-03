locals {
  state_bucket = "${var.name_prefix}-${var.bucket_purpose}-${var.region}"
}

module "terraform_state" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "4.2.2"

  bucket = local.state_bucket

  # Allow deletion of non-empty bucket
  force_destroy = true

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        // TODO: now for simplicity
        sse_algorithm = "AES256"
      }
    }
  }

  versioning = {
    enabled = true
  }

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  attach_deny_insecure_transport_policy = true

  tags = var.state_bucket_tags
}

resource "aws_dynamodb_table" "terraform_state_lock" {
  #checkov:skip=CKV_AWS_28: The terraform state lock is meant to be ephemeral and does not need recovery
  #checkov:skip=CKV_AWS_119: The terraform state lock does not hold any sensitive data
  count        = var.create_dynamodb_table ? 1 : 0
  name         = var.dynamodb_table_name
  hash_key     = "LockID"
  billing_mode = "PAY_PER_REQUEST"


  server_side_encryption {
    enabled = true
  }

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = var.dynamodb_point_in_time_recovery
  }

  tags = var.dynamodb_table_tags
}

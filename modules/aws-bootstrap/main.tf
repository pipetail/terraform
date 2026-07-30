locals {
  state_bucket = "${var.name_prefix}-${var.bucket_purpose}-${var.region}"
  log_bucket   = "${local.state_bucket}-logs"

  create_log_bucket = var.create_log_bucket && length(var.state_bucket_logging) == 0

  state_bucket_logging = local.create_log_bucket ? {
    target_bucket = module.state_logs[0].s3_bucket_id
    target_prefix = "state/"
  } : var.state_bucket_logging
}

// Reads of Terraform state are otherwise unrecorded: state holds every resource
// attribute in plaintext, so s3:GetObject on this bucket is enough to walk the
// whole estate and nothing anywhere shows it happened.
module "state_logs" {
  #checkov:skip=CKV_TF_1:Using registry versioned modules
  #checkov:skip=CKV_AWS_18:This is the access log target; logging it to itself would recurse
  count = local.create_log_bucket ? 1 : 0

  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "4.11.0"

  bucket = local.log_bucket

  force_destroy = var.state_bucket_force_destroy

  // SSE-S3, not the state bucket's key: S3 log delivery cannot write to a
  // bucket encrypted with an SSE-KMS key that has no bucket key.
  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  // Referencing the source bucket by name rather than by
  // module.terraform_state.s3_bucket_arn — that attribute would close a
  // dependency cycle, since the state bucket takes its log target from here.
  attach_access_log_delivery_policy         = true
  access_log_delivery_policy_source_buckets = ["arn:aws:s3:::${local.state_bucket}"]

  control_object_ownership = true
  object_ownership         = "BucketOwnerEnforced"

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  attach_deny_insecure_transport_policy = true

  lifecycle_rule = [
    {
      id      = "expire"
      enabled = true

      expiration = {
        days = var.log_retention_days
      }

      abort_incomplete_multipart_upload_days = 7
    }
  ]

  tags = var.state_bucket_tags
}

module "terraform_state" {
  #checkov:skip=CKV_TF_1:Using registry versioned modules
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "4.11.0"

  bucket = local.state_bucket

  force_destroy = var.state_bucket_force_destroy

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm     = var.state_bucket_kms_key_id == null ? "AES256" : "aws:kms"
        kms_master_key_id = var.state_bucket_kms_key_id
      }
      // null rather than false so leaving the key unset produces no diff on existing buckets
      bucket_key_enabled = var.state_bucket_kms_key_id == null ? null : true
    }
  }

  versioning = {
    enabled = true
  }

  logging = local.state_bucket_logging

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

data "aws_caller_identity" "current" {}

resource "aws_cloudwatch_log_group" "cloudtrail" {
  name = "${var.name_prefix}-cloudtrail-logs"

  kms_key_id        = var.kms_key_arn
  retention_in_days = var.retention_in_days
}

resource "aws_cloudtrail" "main" {
  # checkov:skip=CKV_AWS_252: Ensure CloudTrail defines an SNS Topic: We don't need SNS notifications here
  name           = "${var.name_prefix}-global-events"
  s3_bucket_name = aws_s3_bucket.cloudtrail.id

  enable_log_file_validation = true
  is_multi_region_trail      = true
  is_organization_trail      = false // cannot be true since this is not a management account

  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail.arn
  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail.arn}:*" # CloudTrail requires the Log Stream wildcard

  kms_key_id = var.kms_key_arn

  event_selector {
    exclude_management_event_sources = [
      "kms.amazonaws.com",
      "rdsdata.amazonaws.com"
    ]
  }

  depends_on = [
    aws_s3_bucket_policy.cloudtrail,
  ]
}

resource "aws_s3_bucket" "cloudtrail" {
  # checkov:skip=CKV_AWS_18: Access logging not needed for CloudTrail bucket
  # checkov:skip=CKV_AWS_21: Object versioning not needed here
  # checkov:skip=CKV_AWS_144: Cross-region replication not needed here
  # checkov:skip=CKV2_AWS_62: Event notifications not needed here
  bucket = "${var.name_prefix}-cloudtrail-global-events"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.bucket

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.kms_key_arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail.arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  restrict_public_buckets = true
  block_public_policy     = true

  ignore_public_acls = true
  block_public_acls  = true
}

resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail" {
  #checkov:skip=CKV_AWS_300:Abort incomplete multipart upload is configured in the 'all' rule
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    id     = "all"
    status = "Enabled"

    filter {
      prefix = ""
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 3
    }
  }

  rule {
    id     = "log"
    status = "Enabled"

    expiration {
      days = 90
    }

    filter {
      and {
        prefix = "AWSLogs/"

        tags = {
          rule      = "log"
          autoclean = "true"
        }
      }
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 60
      storage_class = "GLACIER"
    }
  }
}

resource "aws_iam_role" "cloudtrail" {
  name = "cloudtrail-cloudwatch"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "cloudtrail.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "cloudtrail_cloudwatch" {
  name = "cloudtrail"
  role = aws_iam_role.cloudtrail.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AWSCloudTrailCreateLogStream2014110"
        Effect   = "Allow"
        Action   = "logs:CreateLogStream"
        Resource = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
      },
      {
        Sid      = "AWSCloudTrailPutLogEvents20141101"
        Effect   = "Allow"
        Action   = "logs:PutLogEvents"
        Resource = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
      }
    ]
  })
}

resource "aws_cloudtrail" "main" {
  # checkov:skip=CKV2_AWS_10: Not needed here
  # checkov:skip=CKV_AWS_35: TODO: add encryption at rest
  # checkov:skip=CKV_AWS_252: Not needed here
  name           = "${var.name_prefix}-main"
  s3_bucket_name = aws_s3_bucket.cloudtrail.id

  enable_log_file_validation = true
  is_multi_region_trail      = true

  depends_on = [aws_s3_bucket_policy.cloudtrail]
}

resource "aws_s3_bucket" "cloudtrail" {
  # checkov:skip=CKV_AWS_18: Not needed here
  # checkov:skip=CKV2_AWS_6: Not needed here
  # checkov:skip=CKV_AWS_21: Object versioning not needed here
  # checkov:skip=CKV_AWS_145: KMS not needed here
  # checkov:skip=CKV_AWS_144: Not needed here
  bucket = "${var.name_prefix}-cloudtrail"

  force_destroy = true // this is here only because of our terraform destroy workflow
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AWSCloudTrailAclCheck",
            "Effect": "Allow",
            "Principal": {
              "Service": "cloudtrail.amazonaws.com"
            },
            "Action": "s3:GetBucketAcl",
            "Resource": "${aws_s3_bucket.cloudtrail.arn}"
        },
        {
            "Sid": "AWSCloudTrailWrite",
            "Effect": "Allow",
            "Principal": {
              "Service": "cloudtrail.amazonaws.com"
            },
            "Action": "s3:PutObject",
            "Resource": "${aws_s3_bucket.cloudtrail.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*",
            "Condition": {
                "StringEquals": {
                    "s3:x-amz-acl": "bucket-owner-full-control"
                }
            }
        }
    ]
}
POLICY
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  restrict_public_buckets = true
  block_public_policy     = true

  ignore_public_acls = true
  block_public_acls  = true
}

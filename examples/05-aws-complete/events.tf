resource "aws_s3_bucket" "lambda_deployments" {
  #checkov:skip=CKV_AWS_144:Cross-region replication not needed for lambda deployments
  #checkov:skip=CKV_AWS_145:KMS encryption not required for lambda code
  #checkov:skip=CKV2_AWS_62:Event notifications not needed
  #checkov:skip=CKV2_AWS_61:Lifecycle configuration not needed
  #checkov:skip=CKV_AWS_18:Access logging not needed for lambda deployment artifacts
  bucket = "${var.name_prefix}-lambda-deployments"
}

resource "aws_s3_bucket_versioning" "lambda_deployments" {
  bucket = aws_s3_bucket.lambda_deployments.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "lambda_deployments" {
  bucket = aws_s3_bucket.lambda_deployments.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "lambda_deployments" {
  bucket = aws_s3_bucket.lambda_deployments.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

module "aws_events_to_slack" {
  source = "../../modules/aws-events-to-slack"

  s3_deployment_bucket   = aws_s3_bucket.lambda_deployments.id
  account_name           = var.name_prefix
  regions                = var.region
  slack_channel          = var.slack_channel
  notification_emails    = var.notification_emails
  cloudtrail_enabled     = true
  rds_monitoring_enabled = true
}

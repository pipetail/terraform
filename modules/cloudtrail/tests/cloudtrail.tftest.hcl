mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_resource "aws_s3_bucket" {
    defaults = {
      arn = "arn:aws:s3:::example-cloudtrail-global-events"
    }
  }

  mock_resource "aws_cloudwatch_log_group" {
    defaults = {
      arn = "arn:aws:logs:eu-west-1:123456789012:log-group:example-cloudtrail-logs"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/cloudtrail-cloudwatch"
    }
  }
}

variables {
  name_prefix = "example"
  kms_key_arn = "arn:aws:kms:eu-west-1:123456789012:key/00000000-0000-0000-0000-000000000000"
}

run "bucket_policy_lets_only_cloudtrail_write_under_the_account_prefix" {
  command = apply

  assert {
    condition     = length(jsondecode(aws_s3_bucket_policy.cloudtrail.policy).Statement) == 2
    error_message = "The bucket policy must hold only the ACL check and write statements."
  }

  assert {
    condition = alltrue([
      for s in jsondecode(aws_s3_bucket_policy.cloudtrail.policy).Statement :
      s.Effect == "Allow" && s.Principal == { Service = "cloudtrail.amazonaws.com" }
    ])
    error_message = "Every bucket policy statement must grant only the CloudTrail service principal."
  }

  assert {
    condition = [for s in jsondecode(aws_s3_bucket_policy.cloudtrail.policy).Statement : [s.Action, s.Resource]] == [
      ["s3:GetBucketAcl", "arn:aws:s3:::example-cloudtrail-global-events"],
      ["s3:PutObject", "arn:aws:s3:::example-cloudtrail-global-events/AWSLogs/123456789012/*"],
    ]
    error_message = "CloudTrail may read the bucket ACL and write objects only under AWSLogs/<own account id>/."
  }

  assert {
    condition     = jsondecode(aws_s3_bucket_policy.cloudtrail.policy).Statement[1].Condition.StringEquals["s3:x-amz-acl"] == "bucket-owner-full-control"
    error_message = "CloudTrail writes must hand object ownership to the bucket owner."
  }
}

run "bucket_is_kms_encrypted_and_not_public" {
  command = apply

  assert {
    condition = alltrue([
      for r in aws_s3_bucket_server_side_encryption_configuration.cloudtrail.rule :
      r.apply_server_side_encryption_by_default[0].sse_algorithm == "aws:kms"
      && r.apply_server_side_encryption_by_default[0].kms_master_key_id == var.kms_key_arn
    ])
    error_message = "The trail bucket must default to SSE-KMS with the given key."
  }

  assert {
    condition = alltrue([
      aws_s3_bucket_public_access_block.cloudtrail.block_public_acls,
      aws_s3_bucket_public_access_block.cloudtrail.block_public_policy,
      aws_s3_bucket_public_access_block.cloudtrail.ignore_public_acls,
      aws_s3_bucket_public_access_block.cloudtrail.restrict_public_buckets,
    ])
    error_message = "All four public access block settings must be on for the trail bucket."
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.cloudtrail.bucket == aws_s3_bucket.cloudtrail.id
    error_message = "The public access block must target the trail bucket."
  }
}

run "trail_is_multi_region_validated_encrypted_and_keeps_kms_events" {
  command = apply

  assert {
    condition     = aws_cloudtrail.main.is_multi_region_trail && aws_cloudtrail.main.enable_log_file_validation
    error_message = "The trail must cover every region and sign its log files."
  }

  assert {
    condition     = aws_cloudtrail.main.kms_key_id == var.kms_key_arn && aws_cloudwatch_log_group.cloudtrail.kms_key_id == var.kms_key_arn
    error_message = "Trail logs in S3 and in CloudWatch Logs must both be encrypted with the given key."
  }

  assert {
    condition     = !contains(flatten([for s in aws_cloudtrail.main.event_selector : s.exclude_management_event_sources]), "kms.amazonaws.com")
    error_message = "KMS management events must stay in the trail, or ScheduleKeyDeletion and PutKeyPolicy leave no record."
  }

  assert {
    condition     = aws_cloudtrail.main.cloud_watch_logs_group_arn == "arn:aws:logs:eu-west-1:123456789012:log-group:example-cloudtrail-logs:*"
    error_message = "CloudTrail rejects a log group ARN without the :* log stream suffix."
  }
}

run "delivery_role_may_only_write_to_the_trail_log_group" {
  command = apply

  assert {
    condition     = aws_iam_role.cloudtrail.name == "cloudtrail-cloudwatch"
    error_message = "Without an override the delivery role must keep its existing name, or existing trails replace the role."
  }

  assert {
    condition     = jsondecode(aws_iam_role.cloudtrail.assume_role_policy).Statement[0].Principal == { Service = "cloudtrail.amazonaws.com" }
    error_message = "Only CloudTrail may assume the log delivery role."
  }

  assert {
    condition = [for s in jsondecode(aws_iam_role_policy.cloudtrail_cloudwatch.policy).Statement : [s.Action, s.Resource]] == [
      ["logs:CreateLogStream", "arn:aws:logs:eu-west-1:123456789012:log-group:example-cloudtrail-logs:*"],
      ["logs:PutLogEvents", "arn:aws:logs:eu-west-1:123456789012:log-group:example-cloudtrail-logs:*"],
    ]
    error_message = "The delivery role may only create streams in and write events to the trail log group."
  }
}

run "delivery_role_name_can_be_set_per_instance" {
  command = apply

  variables {
    cloudwatch_role_name = "example-cloudtrail-cloudwatch"
  }

  assert {
    condition     = aws_iam_role.cloudtrail.name == "example-cloudtrail-cloudwatch"
    error_message = "IAM role names are unique per account, so a second trail in the account needs its own delivery role name."
  }

  assert {
    condition     = aws_iam_role_policy.cloudtrail_cloudwatch.role == aws_iam_role.cloudtrail.id
    error_message = "The delivery policy must stay attached to the renamed role."
  }
}

run "log_expiry_rule_matches_on_prefix_only" {
  command = apply

  assert {
    condition = alltrue([
      for r in aws_s3_bucket_lifecycle_configuration.cloudtrail.rule :
      r.filter[0].prefix == "AWSLogs/" && length(r.filter[0].tag) == 0 && length(r.filter[0].and) == 0
      && r.expiration[0].days == 90
      if r.id == "log"
    ])
    error_message = "CloudTrail does not tag delivered objects, so a tag filter would make the expiry rule match nothing."
  }

  assert {
    condition     = length([for r in aws_s3_bucket_lifecycle_configuration.cloudtrail.rule : r if r.id == "log"]) == 1
    error_message = "The log expiry rule must exist."
  }
}

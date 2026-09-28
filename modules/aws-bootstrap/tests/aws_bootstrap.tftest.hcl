mock_provider "aws" {
  # The s3-bucket module merges these documents through source_policy_documents,
  # which rejects the random strings the mock provider generates by default.
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

variables {
  name_prefix = "example"
  region      = "eu-west-1"
}

run "state_bucket_is_versioned_and_has_a_bucket_policy" {
  command = apply

  assert {
    condition     = output.state_bucket == "example-tf-state-eu-west-1"
    error_message = "The state bucket must be named <name_prefix>-<bucket_purpose>-<region>, the name documented for the backend block."
  }

  assert {
    condition     = module.terraform_state.aws_s3_bucket_versioning_status == "Enabled"
    error_message = "State bucket versioning must be enabled, it is the only way to recover an overwritten state file."
  }

  assert {
    condition     = module.terraform_state.s3_bucket_policy != ""
    error_message = "The state bucket must carry a bucket policy, the deny-insecure-transport policy is the only one attached."
  }

  assert {
    condition     = local.state_bucket_logging == tomap({ target_bucket = module.state_logs[0].s3_bucket_id, target_prefix = "state/" })
    error_message = "By default the state bucket must log access to the companion log bucket under state/."
  }

  assert {
    condition     = length(module.state_logs) == 1 && local.log_bucket == "example-tf-state-eu-west-1-logs" && output.log_bucket == module.state_logs[0].s3_bucket_id
    error_message = "The companion access log bucket must be created by default."
  }
}

run "no_lock_table_by_default" {
  command = apply

  assert {
    condition     = length(aws_dynamodb_table.terraform_state_lock) == 0
    error_message = "No DynamoDB lock table may be created unless asked for, S3 native locking is the default."
  }

  assert {
    condition     = output.dynamodb_table == null
    error_message = "dynamodb_table must be null when no lock table is created."
  }
}

run "lock_table_toggle_creates_an_encrypted_lockid_table" {
  command = apply

  variables {
    create_dynamodb_table           = true
    dynamodb_table_name             = "example-terraform-state-lock"
    dynamodb_point_in_time_recovery = true
  }

  assert {
    condition     = length(aws_dynamodb_table.terraform_state_lock) == 1
    error_message = "create_dynamodb_table must create exactly one lock table."
  }

  assert {
    condition = (
      aws_dynamodb_table.terraform_state_lock[0].hash_key == "LockID"
      && one(aws_dynamodb_table.terraform_state_lock[0].attribute).name == "LockID"
      && one(aws_dynamodb_table.terraform_state_lock[0].attribute).type == "S"
    )
    error_message = "The S3 backend locks on a string LockID hash key and fails with any other key schema."
  }

  assert {
    condition     = aws_dynamodb_table.terraform_state_lock[0].server_side_encryption[0].enabled
    error_message = "The lock table must be encrypted at rest."
  }

  assert {
    condition     = aws_dynamodb_table.terraform_state_lock[0].point_in_time_recovery[0].enabled
    error_message = "dynamodb_point_in_time_recovery must reach the table."
  }

  assert {
    condition     = aws_dynamodb_table.terraform_state_lock[0].name == "example-terraform-state-lock" && output.dynamodb_table == aws_dynamodb_table.terraform_state_lock[0].id
    error_message = "dynamodb_table must return the lock table name for the backend block."
  }
}

run "external_logging_target_replaces_the_companion_bucket" {
  command = apply

  variables {
    state_bucket_logging = {
      target_bucket = "example-central-logs"
      target_prefix = "tf-state/"
    }
  }

  assert {
    condition     = length(module.state_logs) == 0 && output.log_bucket == null
    error_message = "An explicit state_bucket_logging target must suppress the companion log bucket."
  }

  assert {
    condition     = local.state_bucket_logging == tomap({ target_bucket = "example-central-logs", target_prefix = "tf-state/" })
    error_message = "The state bucket must log to the explicit target unchanged."
  }
}

run "disabling_the_log_bucket_turns_access_logging_off" {
  command = apply

  variables {
    create_log_bucket = false
  }

  assert {
    condition     = length(module.state_logs) == 0 && output.log_bucket == null
    error_message = "create_log_bucket = false must not create the companion log bucket."
  }

  assert {
    condition     = length(local.state_bucket_logging) == 0
    error_message = "With no log bucket and no explicit target the state bucket must not point logging at a bucket that does not exist."
  }
}

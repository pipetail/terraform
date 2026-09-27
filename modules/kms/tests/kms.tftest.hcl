mock_provider "aws" {}

variables {
  region = "eu-west-1"
  key_administrator_arns = [
    "arn:aws:iam::123456789012:role/admin-b",
    "arn:aws:iam::123456789012:role/admin-a",
  ]
}

run "administrators_only_get_a_single_admin_statement" {
  command = plan

  assert {
    condition     = length(jsondecode(aws_kms_key.main.policy).Statement) == 1
    error_message = "With no users, log groups or trails the policy must hold only the administration statement."
  }

  assert {
    condition     = jsondecode(aws_kms_key.main.policy).Statement[0].Principal.AWS == ["arn:aws:iam::123456789012:role/admin-a", "arn:aws:iam::123456789012:role/admin-b"]
    error_message = "The administration statement must name exactly the administrator ARNs."
  }

  assert {
    condition = alltrue([
      for action in jsondecode(aws_kms_key.main.policy).Statement[0].Action : !contains(["kms:Encrypt", "kms:Decrypt", "kms:*", "*"], action)
    ])
    error_message = "Administrators must not be able to encrypt or decrypt data with the key."
  }

  assert {
    condition     = aws_kms_key.main.enable_key_rotation && aws_kms_key.main.is_enabled
    error_message = "Key rotation must be on by default and the key must be enabled."
  }
}

run "key_users_get_use_and_aws_resource_grant_statements" {
  command = plan

  variables {
    key_user_arns = ["arn:aws:iam::123456789012:role/app"]
  }

  assert {
    condition     = [for s in jsondecode(aws_kms_key.main.policy).Statement : s.Sid] == ["Allow key administration", "Allow key use", "Allow grants for AWS resources"]
    error_message = "Key users must add exactly the key use and grant statements."
  }

  assert {
    condition     = jsondecode(aws_kms_key.main.policy).Statement[1].Principal.AWS == ["arn:aws:iam::123456789012:role/app"]
    error_message = "The key use statement must name only the key user ARNs."
  }

  assert {
    condition     = jsondecode(aws_kms_key.main.policy).Statement[2].Condition.Bool["kms:GrantIsForAWSResource"] == "true"
    error_message = "Grants must be limited to AWS resources, or a key user can delegate key use to any principal."
  }
}

run "log_group_statement_is_scoped_to_region_and_arn_patterns" {
  command = plan

  variables {
    cloudwatch_log_group_arn_patterns = ["arn:aws:logs:eu-west-1:123456789012:log-group:/aws/eks/*"]
  }

  assert {
    condition     = jsondecode(aws_kms_key.main.policy).Statement[1].Principal == { Service = "logs.eu-west-1.amazonaws.com" }
    error_message = "The log group statement must trust only the regional CloudWatch Logs service principal."
  }

  assert {
    condition     = jsondecode(aws_kms_key.main.policy).Statement[1].Condition.ArnLike["kms:EncryptionContext:aws:logs:arn"] == ["arn:aws:logs:eu-west-1:123456789012:log-group:/aws/eks/*"]
    error_message = "CloudWatch Logs must be limited to the given log group ARN patterns through the encryption context."
  }
}

run "each_trail_gets_its_own_source_arn_bound_statement" {
  command = plan

  variables {
    cloudtrail_trail_arns = [
      "arn:aws:cloudtrail:eu-west-1:123456789012:trail/org-b",
      "arn:aws:cloudtrail:eu-west-1:123456789012:trail/org-a",
    ]
  }

  assert {
    condition     = [for s in jsondecode(aws_kms_key.main.policy).Statement : s.Sid] == ["Allow key administration", "Allow cloudtrail data key generation 1", "Allow cloudtrail data key generation 2", "Allow cloudtrail key description"]
    error_message = "Each trail must get its own data key statement plus one shared describe statement."
  }

  assert {
    condition = alltrue([
      for s in slice(jsondecode(aws_kms_key.main.policy).Statement, 1, 3) :
      s.Principal == { Service = "cloudtrail.amazonaws.com" }
      && s.Action == "kms:GenerateDataKey*"
      && s.Condition.StringEquals["aws:SourceArn"] == s.Condition.StringEquals["kms:EncryptionContext:aws:cloudtrail:arn"]
    ])
    error_message = "A trail data key statement must bind aws:SourceArn and the encryption context to the same trail, or one trail can write under another trail's context."
  }

  assert {
    condition     = jsondecode(aws_kms_key.main.policy).Statement[1].Condition.StringEquals["aws:SourceArn"] == "arn:aws:cloudtrail:eu-west-1:123456789012:trail/org-a"
    error_message = "Trail statements must be ordered by sorted trail ARN so the policy does not churn."
  }

  assert {
    condition     = jsondecode(aws_kms_key.main.policy).Statement[3].Condition.StringEquals["aws:SourceArn"] == ["arn:aws:cloudtrail:eu-west-1:123456789012:trail/org-a", "arn:aws:cloudtrail:eu-west-1:123456789012:trail/org-b"]
    error_message = "The describe statement must be limited to the given trails."
  }
}

run "rejects_an_empty_administrator_list" {
  command = plan

  variables {
    key_administrator_arns = []
  }

  expect_failures = [var.key_administrator_arns]
}

run "rejects_the_account_root_and_wildcard_trails" {
  command = plan

  variables {
    key_administrator_arns = ["arn:aws:iam::123456789012:root"]
    cloudtrail_trail_arns  = ["arn:aws:cloudtrail:eu-west-1:123456789012:trail/*"]
  }

  expect_failures = [
    var.key_administrator_arns,
    var.cloudtrail_trail_arns,
  ]
}

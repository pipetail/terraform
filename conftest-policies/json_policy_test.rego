package main

import rego.v1

test_iam_policy_document_denied if {
	result := deny_iam_policy_document with input as {"data": {"aws_iam_policy_document": {"my_policy": [{}]}}}
	count(result) == 1
}

test_no_iam_policy_document_allowed if {
	result := deny_iam_policy_document with input as {"data": {}}
	count(result) == 0
}

test_other_data_source_allowed if {
	result := deny_iam_policy_document with input as {"data": {"aws_caller_identity": {"current": [{}]}}}
	count(result) == 0
}

test_heredoc_iam_policy_denied if {
	result := deny_heredoc_json_policy with input as {"resource": {"aws_iam_policy": {"bad": [{"name": "test", "policy": "{\n  \"Version\": \"2012-10-17\"\n}"}]}}}
	count(result) == 1
}

test_heredoc_iam_role_policy_denied if {
	result := deny_heredoc_json_policy with input as {"resource": {"aws_iam_role_policy": {"bad": [{"name": "test", "role": "r", "policy": "{ \"Version\": \"2012-10-17\" }"}]}}}
	count(result) == 1
}

test_heredoc_assume_role_policy_denied if {
	result := deny_heredoc_json_policy with input as {"resource": {"aws_iam_role": {"bad": [{"name": "test", "assume_role_policy": "{\n  \"Version\": \"2012-10-17\"\n}"}]}}}
	count(result) == 1
}

test_heredoc_s3_bucket_policy_denied if {
	result := deny_heredoc_json_policy with input as {"resource": {"aws_s3_bucket_policy": {"bad": [{"bucket": "b", "policy": "{ \"Version\": \"2012-10-17\" }"}]}}}
	count(result) == 1
}

test_heredoc_sns_topic_policy_denied if {
	result := deny_heredoc_json_policy with input as {"resource": {"aws_sns_topic_policy": {"bad": [{"arn": "a", "policy": "{ \"Version\": \"2012-10-17\" }"}]}}}
	count(result) == 1
}

test_heredoc_sqs_queue_policy_denied if {
	result := deny_heredoc_json_policy with input as {"resource": {"aws_sqs_queue_policy": {"bad": [{"queue_url": "q", "policy": "{ \"Version\": \"2012-10-17\" }"}]}}}
	count(result) == 1
}

test_heredoc_kms_key_denied if {
	result := deny_heredoc_json_policy with input as {"resource": {"aws_kms_key": {"bad": [{"policy": "{ \"Version\": \"2012-10-17\" }"}]}}}
	count(result) == 1
}

test_heredoc_ecr_repository_policy_denied if {
	result := deny_heredoc_json_policy with input as {"resource": {"aws_ecr_repository_policy": {"bad": [{"repository": "r", "policy": "{ \"Version\": \"2012-10-17\" }"}]}}}
	count(result) == 1
}

test_heredoc_opensearch_domain_denied if {
	result := deny_heredoc_json_policy with input as {"resource": {"aws_opensearch_domain": {"bad": [{"domain_name": "d", "access_policies": "{ \"Version\": \"2012-10-17\" }"}]}}}
	count(result) == 1
}

test_heredoc_cloudwatch_log_resource_policy_denied if {
	result := deny_heredoc_json_policy with input as {"resource": {"aws_cloudwatch_log_resource_policy": {"bad": [{"policy_name": "p", "policy_document": "{ \"Version\": \"2012-10-17\" }"}]}}}
	count(result) == 1
}

test_heredoc_glacier_vault_denied if {
	result := deny_heredoc_json_policy with input as {"resource": {"aws_glacier_vault": {"bad": [{"name": "v", "access_policy": "{ \"Version\": \"2012-10-17\" }"}]}}}
	count(result) == 1
}

test_jsonencode_iam_policy_allowed if {
	result := deny_heredoc_json_policy with input as {"resource": {"aws_iam_policy": {"good": [{"name": "test", "policy": "${jsonencode({\n    Version = \"2012-10-17\"\n  })}"}]}}}
	count(result) == 0
}

test_jsonencode_assume_role_allowed if {
	result := deny_heredoc_json_policy with input as {"resource": {"aws_iam_role": {"good": [{"name": "test", "assume_role_policy": "${jsonencode({\n    Version = \"2012-10-17\"\n  })}"}]}}}
	count(result) == 0
}

test_jsonencode_s3_bucket_policy_allowed if {
	result := deny_heredoc_json_policy with input as {"resource": {"aws_s3_bucket_policy": {"good": [{"bucket": "b", "policy": "${jsonencode({\n    Version = \"2012-10-17\"\n  })}"}]}}}
	count(result) == 0
}

test_jsonencode_kms_key_allowed if {
	result := deny_heredoc_json_policy with input as {"resource": {"aws_kms_key": {"good": [{"policy": "${jsonencode({\n    Version = \"2012-10-17\"\n  })}"}]}}}
	count(result) == 0
}

test_unrelated_resource_ignored if {
	result := deny_heredoc_json_policy with input as {"resource": {"aws_instance": {"test": [{"ami": "ami-123"}]}}}
	count(result) == 0
}

test_missing_field_ignored if {
	result := deny_heredoc_json_policy with input as {"resource": {"aws_iam_policy": {"test": [{"name": "test"}]}}}
	count(result) == 0
}

test_non_string_value_ignored if {
	result := deny_heredoc_json_policy with input as {"resource": {"aws_iam_policy": {"test": [{"name": "test", "policy": 42}]}}}
	count(result) == 0
}

test_empty_resource_block_ignored if {
	result := deny_heredoc_json_policy with input as {"resource": {"aws_iam_policy": {"test": [{}]}}}
	count(result) == 0
}

test_multiple_violations if {
	result := deny_heredoc_json_policy with input as {"resource": {
		"aws_iam_policy": {"a": [{"policy": "{ \"Version\": \"2012-10-17\" }"}]},
		"aws_s3_bucket_policy": {"b": [{"policy": "{ \"Version\": \"2012-10-17\" }"}]},
	}}
	count(result) == 2
}

# The shapes below are what `conftest parse --parser hcl2` emits for an
# aws_iam_role carrying an inline_policy, written plainly and via a dynamic block.

test_nested_inline_policy_heredoc_denied if {
	result := deny_nested_json_policy with input as {"resource": {"aws_iam_role": {"bad": [{
		"name": "bad",
		"assume_role_policy": "${jsonencode({ Version = \"2012-10-17\" })}",
		"inline_policy": [{"name": "p", "policy": "{ \"Version\": \"2012-10-17\" }\n"}],
	}]}}}
	count(result) == 1
}

test_nested_inline_policy_leading_newline_denied if {
	result := deny_nested_json_policy with input as {"resource": {"aws_iam_role": {"bad": [{"inline_policy": [{"name": "p", "policy": "\n      {\n  \"Version\": \"2012-10-17\"\n}\n"}]}]}}}
	count(result) == 1
}

test_nested_inline_policy_jsonencode_allowed if {
	result := deny_nested_json_policy with input as {"resource": {"aws_iam_role": {"good": [{"inline_policy": [{"name": "p", "policy": "${jsonencode({\n    Version = \"2012-10-17\"\n  })}"}]}]}}}
	count(result) == 0
}

test_dynamic_inline_policy_heredoc_denied if {
	result := deny_nested_json_policy with input as {"resource": {"aws_iam_role": {"bad": [{
		"assume_role_policy": "${jsonencode({ Version = \"2012-10-17\" })}",
		"dynamic": {"inline_policy": [{
			"for_each": ["a"],
			"content": [{"name": "${inline_policy.value}", "policy": "{ \"Version\": \"2012-10-17\" }"}],
		}]},
	}]}}}
	count(result) == 1
}

test_dynamic_inline_policy_jsonencode_allowed if {
	result := deny_nested_json_policy with input as {"resource": {"aws_iam_role": {"good": [{"dynamic": {"inline_policy": [{
		"for_each": ["a"],
		"content": [{"name": "n", "policy": "${jsonencode({ Version = \"2012-10-17\" })}"}],
	}]}}]}}}
	count(result) == 0
}

test_nested_and_dynamic_both_counted if {
	result := deny_nested_json_policy with input as {"resource": {"aws_iam_role": {"bad": [{
		"inline_policy": [{"name": "a", "policy": "{ \"Version\": \"2012-10-17\" }"}],
		"dynamic": {"inline_policy": [{
			"for_each": ["b"],
			"content": [{"name": "b", "policy": "{ \"Version\": \"2012-10-17\" }"}],
		}]},
	}]}}}
	count(result) == 2
}

test_nested_missing_policy_ignored if {
	result := deny_nested_json_policy with input as {"resource": {"aws_iam_role": {"ok": [{"inline_policy": [{"name": "p"}]}]}}}
	count(result) == 0
}

test_nested_non_string_policy_ignored if {
	result := deny_nested_json_policy with input as {"resource": {"aws_iam_role": {"ok": [{"inline_policy": [{"policy": 42}]}]}}}
	count(result) == 0
}

test_unrelated_nested_block_ignored if {
	result := deny_nested_json_policy with input as {"resource": {"aws_iam_role": {"ok": [{"tags": [{"policy": "{ \"a\": 1 }"}]}]}}}
	count(result) == 0
}

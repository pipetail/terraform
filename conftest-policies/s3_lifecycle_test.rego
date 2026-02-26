package main

import rego.v1

test_locals_with_toplevel_prefix_denied if {
	result := deny_s3_lifecycle_prefix_in_locals with input as {"locals": [{"my_rules": [{
		"id": "bad-rule",
		"prefix": "case-exports/",
		"expiration": {"days": 3},
	}]}]}
	count(result) == 1
}

test_locals_with_filter_prefix_allowed if {
	result := deny_s3_lifecycle_prefix_in_locals with input as {"locals": [{"my_rules": [{
		"id": "good-rule",
		"expiration": {"days": 3},
		"filter": {"prefix": "case-exports/"},
	}]}]}
	count(result) == 0
}

test_locals_without_prefix_allowed if {
	result := deny_s3_lifecycle_prefix_in_locals with input as {"locals": [{"my_rules": [{
		"id": "whole-bucket",
		"expiration": {"days": 1},
	}]}]}
	count(result) == 0
}

test_locals_non_lifecycle_object_ignored if {
	result := deny_s3_lifecycle_prefix_in_locals with input as {"locals": [{"some_config": [{
		"prefix": "something/",
		"value": "test",
	}]}]}
	count(result) == 0
}

test_module_inline_lifecycle_with_toplevel_prefix_denied if {
	result := deny_s3_lifecycle_prefix_in_module with input as {"module": {"my_bucket": [{"lifecycle_rule": [{
		"id": "bad-rule",
		"prefix": "uploads/",
		"expiration": {"days": 7},
	}]}]}}
	count(result) == 1
}

test_module_inline_lifecycle_with_filter_allowed if {
	result := deny_s3_lifecycle_prefix_in_module with input as {"module": {"my_bucket": [{"lifecycle_rule": [{
		"id": "good-rule",
		"expiration": {"days": 7},
		"filter": {"prefix": "uploads/"},
	}]}]}}
	count(result) == 0
}

test_resource_lifecycle_config_with_toplevel_prefix_denied if {
	result := deny_s3_lifecycle_prefix_in_resource with input as {"resource": {"aws_s3_bucket_lifecycle_configuration": {"my_bucket": [{"rule": [{
		"id": "bad-rule",
		"prefix": "logs/",
		"status": "Enabled",
		"expiration": [{"days": 30}],
	}]}]}}}
	count(result) == 1
}

test_resource_lifecycle_config_with_filter_allowed if {
	result := deny_s3_lifecycle_prefix_in_resource with input as {"resource": {"aws_s3_bucket_lifecycle_configuration": {"my_bucket": [{"rule": [{
		"id": "good-rule",
		"status": "Enabled",
		"expiration": [{"days": 30}],
		"filter": [{"prefix": "logs/"}],
	}]}]}}}
	count(result) == 0
}

test_transition_rule_with_toplevel_prefix_denied if {
	result := deny_s3_lifecycle_prefix_in_locals with input as {"locals": [{"my_rules": [{
		"id": "archive-rule",
		"prefix": "data/",
		"transition": {"days": 90, "storage_class": "GLACIER"},
	}]}]}
	count(result) == 1
}

package main

import rego.v1

test_dynamodb_unencrypted_denied if {
	result := deny_dynamodb_unencrypted with input as {"resource": {"aws_dynamodb_table": {"unencrypted": [{"server_side_encryption": [{"enabled": false}]}]}}}
	count(result) == 1
}

test_dynamodb_encrypted_allowed if {
	result := deny_dynamodb_unencrypted with input as {"resource": {"aws_dynamodb_table": {"encrypted": [{"server_side_encryption": [{"enabled": true}]}]}}}
	count(result) == 0
}

test_dynamodb_encryption_block_absent_denied if {
	result := deny_dynamodb_unencrypted with input as {"resource": {"aws_dynamodb_table": {"bare": [{"hash_key": "LockID"}]}}}
	count(result) == 1
}

test_dynamodb_encryption_from_variable_allowed if {
	result := deny_dynamodb_unencrypted with input as {"resource": {"aws_dynamodb_table": {"from_var": [{"server_side_encryption": [{"enabled": "${var.encrypt}"}]}]}}}
	count(result) == 0
}

test_dynamodb_pitr_disabled_denied if {
	result := deny_dynamodb_pitr_disabled with input as {"resource": {"aws_dynamodb_table": {"no_pitr": [{"point_in_time_recovery": [{"enabled": false}]}]}}}
	count(result) == 1
}

test_dynamodb_pitr_enabled_allowed if {
	result := deny_dynamodb_pitr_disabled with input as {"resource": {"aws_dynamodb_table": {"with_pitr": [{"point_in_time_recovery": [{"enabled": true}]}]}}}
	count(result) == 0
}

test_dynamodb_pitr_block_absent_denied if {
	result := deny_dynamodb_pitr_disabled with input as {"resource": {"aws_dynamodb_table": {"bare": [{"hash_key": "LockID"}]}}}
	count(result) == 1
}

test_dynamodb_pitr_from_variable_allowed if {
	result := deny_dynamodb_pitr_disabled with input as {"resource": {"aws_dynamodb_table": {"from_var": [{"point_in_time_recovery": [{"enabled": "${var.pitr}"}]}]}}}
	count(result) == 0
}

test_dynamodb_replica_missing_warning if {
	result := warn_dynamodb_replica_missing with input as {"resource": {"aws_dynamodb_table": {"single_region": [{"billing_mode": "PAY_PER_REQUEST"}]}}}
	count(result) == 1
}

test_dynamodb_with_replica_allowed if {
	result := warn_dynamodb_replica_missing with input as {"resource": {"aws_dynamodb_table": {"multi_region": [{"billing_mode": "PAY_PER_REQUEST", "replica": [{"region_name": "us-east-1"}]}]}}}
	count(result) == 0
}

test_dynamodb_provisioned_without_replica_allowed if {
	result := warn_dynamodb_replica_missing with input as {"resource": {"aws_dynamodb_table": {"provisioned": [{"billing_mode": "PROVISIONED"}]}}}
	count(result) == 0
}

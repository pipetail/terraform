package main

import rego.v1

test_dynamodb_unencrypted_denied if {
	result := deny_dynamodb_unencrypted with input as {"resource": {"aws_dynamodb_table": {"unencrypted": [{"server_side_encryption": false}]}}}
	count(result) == 1
}

test_dynamodb_encrypted_allowed if {
	result := deny_dynamodb_unencrypted with input as {"resource": {"aws_dynamodb_table": {"encrypted": [{"server_side_encryption": true}]}}}
	count(result) == 0
}

test_dynamodb_pitr_disabled_denied if {
	result := deny_dynamodb_pitr_disabled with input as {"resource": {"aws_dynamodb_table": {"no_pitr": [{"point_in_time_recovery": false}]}}}
	count(result) == 1
}

test_dynamodb_pitr_enabled_allowed if {
	result := deny_dynamodb_pitr_disabled with input as {"resource": {"aws_dynamodb_table": {"with_pitr": [{"point_in_time_recovery": true}]}}}
	count(result) == 0
}

test_dynamodb_replica_missing_warning if {
	result := deny_dynamodb_replica_missing with input as {"resource": {"aws_dynamodb_table": {"single_region": [{"billing_mode": "PAY_PER_REQUEST"}]}}}
	count(result) == 1
}

test_dynamodb_with_replica_allowed if {
	result := deny_dynamodb_replica_missing with input as {"resource": {"aws_dynamodb_table": {"multi_region": [{"billing_mode": "PAY_PER_REQUEST", "replica": [{"region_name": "us-east-1"}]}]}}}
	count(result) == 0
}

test_dynamodb_provisioned_without_replica_allowed if {
	result := deny_dynamodb_replica_missing with input as {"resource": {"aws_dynamodb_table": {"provisioned": [{"billing_mode": "PROVISIONED"}]}}}
	count(result) == 0
}

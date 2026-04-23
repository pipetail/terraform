package main

import rego.v1

test_rds_instance_unencrypted_denied if {
	result := deny_rds_unencrypted with input as {"resource": {"aws_db_instance": {"unencrypted": [{"storage_encrypted": false}]}}}
	count(result) == 1
}

test_rds_instance_encrypted_allowed if {
	result := deny_rds_unencrypted with input as {"resource": {"aws_db_instance": {"encrypted": [{"storage_encrypted": true}]}}}
	count(result) == 0
}

test_rds_instance_default_encrypted_allowed if {
	result := deny_rds_unencrypted with input as {"resource": {"aws_db_instance": {"default": [{}]}}}
	count(result) == 0
}

test_rds_cluster_unencrypted_denied if {
	result := deny_rds_unencrypted with input as {"resource": {"aws_rds_cluster": {"unencrypted": [{"storage_encrypted": false}]}}}
	count(result) == 1
}

test_rds_cluster_encrypted_allowed if {
	result := deny_rds_unencrypted with input as {"resource": {"aws_rds_cluster": {"encrypted": [{"storage_encrypted": true}]}}}
	count(result) == 0
}

test_rds_cluster_instance_unencrypted_denied if {
	result := deny_rds_unencrypted with input as {"resource": {"aws_rds_cluster_instance": {"unencrypted": [{"storage_encrypted": false}]}}}
	count(result) == 1
}

test_rds_cluster_instance_encrypted_allowed if {
	result := deny_rds_unencrypted with input as {"resource": {"aws_rds_cluster_instance": {"encrypted": [{"storage_encrypted": true}]}}}
	count(result) == 0
}

test_rds_skip_final_snapshot_denied if {
	result := deny_rds_skip_final_snapshot with input as {"resource": {"aws_db_instance": {"no_snapshot": [{"skip_final_snapshot": true}]}}}
	count(result) == 1
}

test_rds_skip_final_snapshot_allowed if {
	result := deny_rds_skip_final_snapshot with input as {"resource": {"aws_db_instance": {"with_snapshot": [{"skip_final_snapshot": false}]}}}
	count(result) == 0
}

test_rds_cluster_skip_final_snapshot_denied if {
	result := deny_rds_skip_final_snapshot with input as {"resource": {"aws_rds_cluster": {"no_snapshot": [{"skip_final_snapshot": true}]}}}
	count(result) == 1
}

test_rds_cluster_skip_final_snapshot_allowed if {
	result := deny_rds_skip_final_snapshot with input as {"resource": {"aws_rds_cluster": {"with_snapshot": [{"skip_final_snapshot": false}]}}}
	count(result) == 0
}

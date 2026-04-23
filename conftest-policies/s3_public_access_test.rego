package main

import rego.v1

test_s3_bucket_public_acl_denied if {
	result := deny_s3_public_access with input as {"resource": {"aws_s3_bucket": {"public": [{"acl": "public-read"}]}}}
	count(result) == 1
}

test_s3_bucket_private_acl_allowed if {
	result := deny_s3_public_access with input as {"resource": {"aws_s3_bucket": {"private": [{"acl": "private"}]}}}
	count(result) == 0
}

test_s3_bucket_log_delivery_acl_allowed if {
	result := deny_s3_public_access with input as {"resource": {"aws_s3_bucket": {"logs": [{"acl": "log_delivery_write"}]}}}
	count(result) == 0
}

test_s3_public_access_block_disabled_denied if {
	result := deny_s3_public_access_block_disabled with input as {"resource": {"aws_s3_bucket_public_access_block": {"bad": [{"block_public_acls": false}]}}}
	count(result) == 1
}

test_s3_public_access_block_enabled_allowed if {
	result := deny_s3_public_access_block_disabled with input as {"resource": {"aws_s3_bucket_public_access_block": {"good": [{"block_public_acls": true, "block_public_policy": true, "ignore_public_acls": true, "restrict_public_buckets": true}]}}}
	count(result) == 0
}

test_s3_public_access_block_partial_allowed if {
	result := deny_s3_public_access_block_disabled with input as {"resource": {"aws_s3_bucket_public_access_block": {"partial": [{"block_public_acls": true, "block_public_policy": false}]}}}
	count(result) == 1
}

package main

import rego.v1

deny_s3_public_access contains msg if {
	some name
	some block in input.resource.aws_s3_bucket[name]
	object.get(block, "acl", "") != "private"
	object.get(block, "acl", "") != "log_delivery_write"
	msg := sprintf(
		"aws_s3_bucket.%s: bucket ACL should be 'private', got '%s'",
		[name, block.acl],
	)
}

deny_s3_public_access_block_disabled contains msg if {
	some name
	some block in input.resource.aws_s3_bucket_public_access_block[name]
	block.block_public_acls != true
	msg := sprintf(
		"aws_s3_bucket_public_access_block.%s: block_public_acls should be true",
		[name],
	)
}

deny_s3_public_access_block_disabled contains msg if {
	some name
	some block in input.resource.aws_s3_bucket_public_access_block[name]
	block.block_public_policy != true
	msg := sprintf(
		"aws_s3_bucket_public_access_block.%s: block_public_policy should be true",
		[name],
	)
}

deny_s3_public_access_block_disabled contains msg if {
	some name
	some block in input.resource.aws_s3_bucket_public_access_block[name]
	block.ignore_public_acls != true
	msg := sprintf(
		"aws_s3_bucket_public_access_block.%s: ignore_public_acls should be true",
		[name],
	)
}

deny_s3_public_access_block_disabled contains msg if {
	some name
	some block in input.resource.aws_s3_bucket_public_access_block[name]
	block.restrict_public_buckets != true
	msg := sprintf(
		"aws_s3_bucket_public_access_block.%s: restrict_public_buckets should be true",
		[name],
	)
}

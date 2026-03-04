package main

import rego.v1

deny_dynamodb_unencrypted contains msg if {
	some name
	some block in input.resource.aws_dynamodb_table[name]
	object.get(block, "server_side_encryption", false) != true
	msg := sprintf(
		"aws_dynamodb_table.%s: server_side_encryption must be true",
		[name],
	)
}

deny_dynamodb_replica_missing contains msg if {
	some name
	some block in input.resource.aws_dynamodb_table[name]
	object.get(block, "replica", null) == null
	object.get(block, "billing_mode", "PAY_PER_REQUEST") == "PAY_PER_REQUEST"
	not contains(name, "-replica-")
	not contains(name, "_replica_")
	msg := sprintf(
		"aws_dynamodb_table.%s: consider adding replica for multi-region redundancy",
		[name],
	)
}

deny_dynamodb_pitr_disabled contains msg if {
	some name
	some block in input.resource.aws_dynamodb_table[name]
	object.get(block, "point_in_time_recovery", false) != true
	msg := sprintf(
		"aws_dynamodb_table.%s: point_in_time_recovery should be enabled",
		[name],
	)
}

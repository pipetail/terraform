package main

import rego.v1

# server_side_encryption and point_in_time_recovery are HCL blocks, so the hcl2 parser
# yields a list of objects, never a bare boolean. An attribute that references a variable
# arrives as an unresolved "${var.x}" string that no static check can evaluate, so only a
# literal false counts as a violation.

sse_enabled(block) if {
	some sse in block.server_side_encryption
	sse.enabled != false
}

pitr_enabled(block) if {
	some pitr in block.point_in_time_recovery
	pitr.enabled != false
}

deny_dynamodb_unencrypted contains msg if {
	some name
	some block in input.resource.aws_dynamodb_table[name]
	not sse_enabled(block)
	msg := sprintf(
		"aws_dynamodb_table.%s: server_side_encryption must be enabled",
		[name],
	)
}

warn_dynamodb_replica_missing contains msg if {
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
	not pitr_enabled(block)
	msg := sprintf(
		"aws_dynamodb_table.%s: point_in_time_recovery should be enabled",
		[name],
	)
}

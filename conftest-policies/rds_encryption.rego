package main

import rego.v1

deny_rds_unencrypted contains msg if {
	some name
	some block in input.resource.aws_db_instance[name]
	object.get(block, "storage_encrypted", true) != true
	msg := sprintf(
		"aws_db_instance.%s: storage_encrypted must be true",
		[name],
	)
}

deny_rds_unencrypted contains msg if {
	some name
	some block in input.resource.aws_rds_cluster[name]
	object.get(block, "storage_encrypted", true) != true
	msg := sprintf(
		"aws_rds_cluster.%s: storage_encrypted must be true",
		[name],
	)
}

deny_rds_unencrypted contains msg if {
	some name
	some block in input.resource.aws_rds_cluster_instance[name]
	object.get(block, "storage_encrypted", true) != true
	msg := sprintf(
		"aws_rds_cluster_instance.%s: storage_encrypted must be true",
		[name],
	)
}

deny_rds_skip_final_snapshot contains msg if {
	some name
	some block in input.resource.aws_db_instance[name]
	object.get(block, "skip_final_snapshot", false) == true
	msg := sprintf(
		"aws_db_instance.%s: skip_final_snapshot should be false for production databases",
		[name],
	)
}

deny_rds_skip_final_snapshot contains msg if {
	some name
	some block in input.resource.aws_rds_cluster[name]
	object.get(block, "skip_final_snapshot", false) == true
	msg := sprintf(
		"aws_rds_cluster.%s: skip_final_snapshot should be false for production databases",
		[name],
	)
}

package main

import rego.v1

deny_iam_policy_document contains msg if {
	some name
	input.data.aws_iam_policy_document[name]
	msg := sprintf(
		"data.aws_iam_policy_document.%s: use jsonencode() for IAM policies instead of aws_iam_policy_document data sources",
		[name],
	)
}

policy_fields := {
	"aws_iam_policy": ["policy"],
	"aws_iam_role": ["assume_role_policy"],
	"aws_iam_role_policy": ["policy"],
	"aws_iam_group_policy": ["policy"],
	"aws_iam_user_policy": ["policy"],
	"aws_s3_bucket_policy": ["policy"],
	"aws_s3_bucket": ["policy"],
	"aws_s3_access_point": ["policy"],
	"aws_s3control_access_point_policy": ["policy"],
	"aws_sns_topic_policy": ["policy"],
	"aws_sns_topic": ["policy"],
	"aws_sqs_queue_policy": ["policy"],
	"aws_sqs_queue": ["policy"],
	"aws_kms_key": ["policy"],
	"aws_kms_key_policy": ["policy"],
	"aws_ecr_repository_policy": ["policy"],
	"aws_secretsmanager_secret_policy": ["policy"],
	"aws_cloudwatch_log_resource_policy": ["policy_document"],
	"aws_opensearch_domain": ["access_policies"],
	"aws_opensearch_domain_policy": ["access_policies"],
	"aws_elasticsearch_domain_policy": ["access_policies"],
	"aws_api_gateway_rest_api_policy": ["policy"],
	"aws_glacier_vault": ["access_policy"],
	"aws_media_store_container_policy": ["policy"],
	"aws_backup_vault_policy": ["policy"],
	"aws_efs_file_system_policy": ["policy"],
}

raw_json_field(block, field) if {
	value := object.get(block, field, "")
	is_string(value)
	startswith(trim_space(value), "{")
}

deny_heredoc_json_policy contains msg if {
	some res_type, fields in policy_fields
	some name
	some block in input.resource[res_type][name]
	some field in fields
	raw_json_field(block, field)
	msg := sprintf(
		"%s.%s: '%s' uses a raw JSON string — use jsonencode() instead",
		[res_type, name, field],
	)
}

# Policy fields that live in a nested block rather than on the resource itself. The
# lookups above only read top-level attributes, so without these a raw JSON policy
# inside one of these blocks reaches AWS unchecked.
nested_policy_fields := {"aws_iam_role": {"inline_policy": ["policy"]}}

deny_nested_json_policy contains msg if {
	some res_type, nested in nested_policy_fields
	some name
	some block in input.resource[res_type][name]
	some nested_type, fields in nested
	some nested_block in block[nested_type]
	some field in fields
	raw_json_field(nested_block, field)
	msg := sprintf(
		"%s.%s: '%s.%s' uses a raw JSON string — use jsonencode() instead",
		[res_type, name, nested_type, field],
	)
}

# The same nested blocks written as `dynamic "<block>" { content { ... } }`. The hcl2
# parser keeps a dynamic block under its own `dynamic` key, so the plain nested lookup
# never reaches the generated content.
deny_nested_json_policy contains msg if {
	some res_type, nested in nested_policy_fields
	some name
	some block in input.resource[res_type][name]
	some nested_type, fields in nested
	some dyn in block.dynamic[nested_type]
	some content in dyn.content
	some field in fields
	raw_json_field(content, field)
	msg := sprintf(
		"%s.%s: dynamic '%s' content '%s' uses a raw JSON string — use jsonencode() instead",
		[res_type, name, nested_type, field],
	)
}

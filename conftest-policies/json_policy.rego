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

deny_heredoc_json_policy contains msg if {
	some res_type, fields in policy_fields
	some name
	some block in input.resource[res_type][name]
	some field in fields
	value := object.get(block, field, "")
	is_string(value)
	startswith(trim_space(value), "{")
	msg := sprintf(
		"%s.%s: '%s' uses a raw JSON string — use jsonencode() instead",
		[res_type, name, field],
	)
}

package main

import rego.v1

deny_s3_lifecycle_prefix_in_locals contains msg if {
	some block in input.locals
	some name, rules in block
	is_array(rules)
	some rule in rules
	is_lifecycle_rule(rule)
	object.get(rule, "prefix", "__absent__") != "__absent__"
	msg := sprintf(
		"locals.%s: lifecycle rule '%s' has 'prefix' as a top-level key — move it inside a filter block: filter = { prefix = \"...\" }",
		[name, rule.id],
	)
}

deny_s3_lifecycle_prefix_in_module contains msg if {
	some mod_name
	some block in input.module[mod_name]
	rules := block.lifecycle_rule
	is_array(rules)
	some rule in rules
	is_lifecycle_rule(rule)
	object.get(rule, "prefix", "__absent__") != "__absent__"
	msg := sprintf(
		"module.%s: lifecycle rule '%s' has 'prefix' as a top-level key — move it inside a filter block: filter = { prefix = \"...\" }",
		[mod_name, rule.id],
	)
}

deny_s3_lifecycle_prefix_in_resource contains msg if {
	some name
	some block in input.resource.aws_s3_bucket_lifecycle_configuration[name]
	some rule in block.rule
	object.get(rule, "prefix", "__absent__") != "__absent__"
	msg := sprintf(
		"aws_s3_bucket_lifecycle_configuration.%s: rule '%s' has 'prefix' as a top-level key — use a filter block instead",
		[name, rule.id],
	)
}

is_lifecycle_rule(rule) if {
	rule.id
	object.get(rule, "expiration", null) != null
}

is_lifecycle_rule(rule) if {
	rule.id
	object.get(rule, "transition", null) != null
}

is_lifecycle_rule(rule) if {
	rule.id
	object.get(rule, "noncurrent_version_expiration", null) != null
}

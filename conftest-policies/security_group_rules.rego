package main

import rego.v1

deny_insecure_security_group_ingress contains msg if {
	some name, blocks in input.resource.aws_security_group
	some block in blocks
	some rule in object.get(block, "ingress", [])
	some cidr in object.get(rule, "cidr_blocks", [])
	cidr == "0.0.0.0/0"
	msg := sprintf(
		"aws_security_group.%s: ingress rule allows 0.0.0.0/0 - restrict to specific IPs",
		[name],
	)
}

deny_insecure_security_group_ingress contains msg if {
	some name, blocks in input.resource.aws_security_group
	some block in blocks
	some rule in object.get(block, "ingress", [])
	some cidr in object.get(rule, "ipv6_cidr_blocks", [])
	cidr == "::/0"
	msg := sprintf(
		"aws_security_group.%s: ingress rule allows ::/0 - restrict to specific IPv6 ranges",
		[name],
	)
}

deny_insecure_security_group_egress contains msg if {
	some name, blocks in input.resource.aws_security_group
	some block in blocks
	some rule in object.get(block, "egress", [])
	some cidr in object.get(rule, "cidr_blocks", [])
	cidr == "0.0.0.0/0"
	msg := sprintf(
		"aws_security_group.%s: egress rule allows 0.0.0.0/0 - restrict to specific IPs",
		[name],
	)
}

deny_insecure_security_group_egress contains msg if {
	some name, blocks in input.resource.aws_security_group
	some block in blocks
	some rule in object.get(block, "egress", [])
	some cidr in object.get(rule, "ipv6_cidr_blocks", [])
	cidr == "::/0"
	msg := sprintf(
		"aws_security_group.%s: egress rule allows ::/0 - restrict to specific IPv6 ranges",
		[name],
	)
}

deny_security_group_without_description contains msg if {
	some name, blocks in input.resource.aws_security_group
	some block in blocks
	object.get(block, "description", "") == ""
	msg := sprintf(
		"aws_security_group.%s: security group must have a description",
		[name],
	)
}

deny_security_group_rule_without_description contains msg if {
	some name, blocks in input.resource.aws_security_group
	some block in blocks
	some rule in object.get(block, "ingress", [])
	object.get(rule, "description", "") == ""
	msg := sprintf(
		"aws_security_group.%s: ingress rule must have a description",
		[name],
	)
}

deny_security_group_rule_without_description contains msg if {
	some name, blocks in input.resource.aws_security_group
	some block in blocks
	some rule in object.get(block, "egress", [])
	object.get(rule, "description", "") == ""
	msg := sprintf(
		"aws_security_group.%s: egress rule must have a description",
		[name],
	)
}

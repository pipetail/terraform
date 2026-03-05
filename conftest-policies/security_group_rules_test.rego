package main

import rego.v1

test_sg_ingress_0_0_0_0_denied if {
	result := deny_insecure_security_group_ingress with input as {"resource": {"aws_security_group": {"bad": [{"ingress": [{"cidr_blocks": ["0.0.0.0/0"]}]}]}}}
	count(result) == 1
}

test_sg_ingress_specific_ip_allowed if {
	result := deny_insecure_security_group_ingress with input as {"resource": {"aws_security_group": {"good": [{"ingress": [{"cidr_blocks": ["10.0.0.0/8"]}]}]}}}
	count(result) == 0
}

test_sg_ingress_ipv6_all_denied if {
	result := deny_insecure_security_group_ingress with input as {"resource": {"aws_security_group": {"bad_ipv6": [{"ingress": [{"ipv6_cidr_blocks": ["::/0"]}]}]}}}
	count(result) == 1
}

test_sg_egress_0_0_0_0_denied if {
	result := deny_insecure_security_group_egress with input as {"resource": {"aws_security_group": {"bad": [{"egress": [{"cidr_blocks": ["0.0.0.0/0"]}]}]}}}
	count(result) == 1
}

test_sg_egress_specific_ip_allowed if {
	result := deny_insecure_security_group_egress with input as {"resource": {"aws_security_group": {"good": [{"egress": [{"cidr_blocks": ["10.0.0.0/8"]}]}]}}}
	count(result) == 0
}

test_sg_without_description_denied if {
	result := deny_security_group_without_description with input as {"resource": {"aws_security_group": {"no_desc": [{}]}}}
	count(result) == 1
}

test_sg_with_description_allowed if {
	result := deny_security_group_without_description with input as {"resource": {"aws_security_group": {"with_desc": [{"description": "Security group"}]}}}
	count(result) == 0
}

test_sg_rule_without_description_denied if {
	result := deny_security_group_rule_without_description with input as {"resource": {"aws_security_group": {"bad": [{"ingress": [{"description": ""}]}]}}}
	count(result) == 1
}

test_sg_rule_with_description_allowed if {
	result := deny_security_group_rule_without_description with input as {"resource": {"aws_security_group": {"good": [{"ingress": [{"description": "Allow HTTP"}]}]}}}
	count(result) == 0
}

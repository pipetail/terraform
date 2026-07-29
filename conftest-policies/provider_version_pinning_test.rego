package main

import rego.v1

required_providers(version_constraint) := {"terraform": [{"required_providers": [{"aws": {
	"source": "hashicorp/aws",
	"version": version_constraint,
}}]}]}

test_loose_constraint_denied if {
	result := deny_unpinned_provider_version with input as required_providers(">= 4.66.0")
	count(result) == 1
}

test_exact_pin_allowed if {
	result := deny_unpinned_provider_version with input as required_providers("4.67.0")
	count(result) == 0
}

test_tilde_constraint_allowed if {
	result := deny_unpinned_provider_version with input as required_providers("~> 4.67.0")
	count(result) == 0
}

test_upper_bound_allowed if {
	result := deny_unpinned_provider_version with input as required_providers(">= 4.66.0, < 6.0.0")
	count(result) == 0
}

test_missing_version_allowed if {
	result := deny_unpinned_provider_version with input as {"terraform": [{"required_providers": [{"aws": {"source": "hashicorp/aws"}}]}]}
	count(result) == 0
}

test_no_terraform_block_allowed if {
	result := deny_unpinned_provider_version with input as {"resource": {"aws_s3_bucket": {"example": [{"bucket": "example"}]}}}
	count(result) == 0
}

test_every_loose_provider_reported if {
	result := deny_unpinned_provider_version with input as {"terraform": [{"required_providers": [{
		"aws": {"source": "hashicorp/aws", "version": ">= 4.0.0"},
		"tls": {"source": "hashicorp/tls", "version": ">= 4.0.0"},
		"random": {"source": "hashicorp/random", "version": "~> 3.0"},
	}]}]}
	count(result) == 2
}

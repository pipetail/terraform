package main

import rego.v1

test_provider_tilde_version_allowed if {
	result := deny_unpinned_provider_version with input as {"resource": {"terraform": {"main": {"required_providers": {"aws": {"source": "hashicorp/aws", "version": "~> 4.66.0"}}}}}}
	count(result) == 0
}

test_provider_exact_version_allowed if {
	result := deny_unpinned_provider_version with input as {"resource": {"terraform": {"main": {"required_providers": {"aws": {"source": "hashicorp/aws", "version": "= 4.66.0"}}}}}}
	count(result) == 0
}

test_provider_no_version_allowed if {
	result := deny_unpinned_provider_version with input as {"resource": {"terraform": {"main": {"required_providers": {"aws": {"source": "hashicorp/aws"}}}}}}
	count(result) == 0
}

test_provider_greater_less_than_allowed if {
	result := deny_unpinned_provider_version with input as {"resource": {"terraform": {"main": {"required_providers": {"aws": {"source": "hashicorp/aws", "version": ">= 4.66.0, < 6.0.0"}}}}}}
	count(result) == 0
}

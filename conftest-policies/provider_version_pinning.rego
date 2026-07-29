package main

import rego.v1

# terraform and required_providers are HCL blocks, so the hcl2 parser puts them at the top
# level as lists of objects - not under input.resource, and not as a single object.

deny_unpinned_provider_version contains msg if {
	some tf in input.terraform
	some required in tf.required_providers
	some name, provider in required
	version_constraint := object.get(provider, "version", "")
	version_constraint != ""
	startswith(version_constraint, ">=")
	not contains(version_constraint, "~>")
	not contains(version_constraint, "<")
	msg := sprintf(
		"provider '%s' has loose version constraint '%s' - pin to a specific version, use '~>', or add an upper bound",
		[name, version_constraint],
	)
}

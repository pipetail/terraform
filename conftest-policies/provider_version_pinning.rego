package main

import rego.v1

deny_unpinned_provider_version contains msg if {
	some path, block in input.resource.terraform
	some name, provider in object.get(block, "required_providers", {})
	version_constraint := object.get(provider, "version", "")
	version_constraint != ""
	not contains(version_constraint, "~>")
	not contains(version_constraint, "=")
	not contains(version_constraint, "<")
	msg := sprintf(
		"%s/versions.tf: provider '%s' has loose version constraint '%s' - pin to specific version or use '~>' for minor version pinning",
		[path, name, version_constraint],
	)
}

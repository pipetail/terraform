---
name: tf-lock
description: Use when a provider version or required_providers block changes in a versions.tf or main.tf, when a .terraform.lock.hcl changes or looks macOS-only, when a Renovate provider bump needs relocking, or when the "Verify Terraform lock files" check (terraform-lock.yaml) fails on a PR.
user-invocable: true
argument-hint: '[example dir]'
allowed-tools: Bash, Read
---

# tf-lock

Lock files are committed only in the example roots under `examples/`. Module lock files are
gitignored. Never hand-edit a `.terraform.lock.hcl`; regenerate it.

## What CI checks

`terraform-lock.yaml` runs on PRs that touch a `versions.tf`, a `.terraform.lock.hcl` or
`renovate.json`. For every directory that has a lock file it runs:

```bash
terraform init -backend=false -upgrade
terraform providers lock -platform=windows_amd64 -platform=darwin_amd64 -platform=linux_amd64 -platform=darwin_arm64 -platform=linux_arm64
```

and fails if either command changed a committed lock file. Two things follow:

- The lock must record the newest provider version the constraints allow, because `-upgrade`
  picks that version. A lock pinned to an older allowed version fails.
- The lock must carry hashes for all five platforms. A lock written by a plain `terraform init` on
  a Mac holds only that Mac's platform and fails.

The check skips PRs from forks.

## Regenerate

Run the same two commands in each affected example root. `$ARGUMENTS` may name one; otherwise
relock every directory under `examples/` that has a `.terraform.lock.hcl`.

Which roots are affected:

- the root whose `versions.tf` or `required_providers` changed
- every example that calls a module whose `versions.tf` changed, because the module's
  constraints narrow what the example can select
  (find them with `grep -rn 'modules/<name>"' examples/`)

`init -backend=false` is fine here: it only resolves providers and never touches state.

## Verify

```bash
git diff --stat -- '**/.terraform.lock.hcl'
awk '/^provider/{p=$2} /"h1:/{c[p]++} END{for(k in c) print k, c[k]}' <dir>/.terraform.lock.hcl
```

Every provider must show 5 `h1:` hashes, one per platform. Fewer means a `-platform` flag was
missing; rerun the lock command.

Stage only the lock files you meant to change. `init` also rewrites lock files in any other root you
ran it in, and those do not belong in an unrelated PR.

Commit as `chore(deps): ...` or with the scope of the change that needed the relock.

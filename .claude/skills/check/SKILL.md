---
name: check
description: Use before opening or updating a PR in this repo, when asked to validate, lint or test the Terraform, modules, conftest policies or release scripts, or when the precommit, terraform-test or pr-title CI check fails and needs reproducing locally. Also "/check".
user-invocable: true
argument-hint: '[module or example dir]'
allowed-tools: Bash, Read
---

# check

Run the same checks CI runs on a PR, from the repo root, and report one pass/fail line per step. Keep
going after a failure and report every failure together at the end. Nothing here applies or touches
state.

`$ARGUMENTS` may name a module or example directory to focus the Terraform steps on. Default: every
directory with a changed `.tf` file.

## 1. pre-commit on the changed files

```bash
git fetch origin
pre-commit run --from-ref origin/master --to-ref HEAD
```

This is what `precommit.yaml` runs, so it only covers files the branch changed. Uncommitted edits
are not in that range; run `pre-commit run --files <paths>` for those.

The hooks need `terraform`, `tflint`, `terraform-docs`, `checkov`, `conftest`, `opa` and `shfmt` on
the PATH. `precommit.yaml` pins the versions CI uses. A hook that fails on a file the branch did not
change is a failure that already exists on master: rerun it on `origin/master` before blaming the
branch, and do not fix it in this PR.

Do not use `--all-files` as the pass/fail signal. It checks files CI does not, so its result does not
predict the PR.

## 2. Policies over the whole tree

pre-commit only tests the changed files against the policies. CI also runs them over every file,
because a policy change can pass on its own diff and fail elsewhere:

```bash
conftest verify --policy conftest-policies/ --no-color
git ls-files -z 'examples/*.tf' 'modules/*.tf' | xargs -0 conftest test --parser hcl2 --policy conftest-policies/ --no-color
```

After editing a `.rego` file, also run `opa fmt -w conftest-policies/`. Each policy needs its
`_test.rego` cases to pass under `conftest verify`.

## 3. terraform test for a changed module

`terraform-test.yaml` runs `terraform init` and `terraform test` in every `modules/<name>/` that has
a `tests/` directory, with mock providers and no cloud credentials. Run the suite of each module the
branch changed.

`init` writes `.terraform/` and a lock file into the directory, so run it in a scratch copy and leave
the working tree as git sees it:

```bash
tmp=$(mktemp -d) && cp -R modules/<name> "$tmp/" && (cd "$tmp/<name>" && terraform init -input=false -no-color && terraform test -no-color); rm -rf "$tmp"
```

The suites use `mock_provider`, which needs Terraform 1.7 or newer. `terraform-test.yaml` pins the
version CI uses. A module with no `tests/` directory has nothing to run; say so rather than
reporting a pass.

## 4. tflint

pre-commit already runs tflint on changed directories. To run it directly in one directory, with the
same config and disabled rules as the hook:

```bash
root=$(git rev-parse --show-toplevel) && tflint --init --config "$root/.tflint.hcl" && (cd <dir> && tflint --config "$root/.tflint.hcl" --disable-rule=terraform_standard_module_structure --disable-rule=terraform_unused_required_providers)
```

## 5. Script tests, if their files changed

| Changed | Run |
|---|---|
| `.github/scripts/module-release.mjs` | `node --test 'tests/module-release/*.test.mjs'` |
| `src/aws-events-to-slack/` | `node --test 'tests/aws-events-to-slack/*.test.mjs'` |

## Report

One line per step: `PASS`, `FAIL` with the first error, or `SKIPPED` with the reason (tool missing,
nothing changed). End with a one-line verdict. A skipped step is not a pass.

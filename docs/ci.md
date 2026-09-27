# CI

Every workflow lives in [`.github/workflows`](../.github/workflows). Every action is pinned to a full commit digest, and Renovate bumps the digests.

## On every pull request

| Workflow | What it does |
|---|---|
| `precommit.yaml` | Runs the pre-commit hooks on the files the PR changes, then runs `conftest verify` and `conftest test` over the whole tree. |
| `terraform-test.yaml` | Runs `terraform init` and `terraform test` for every module that has a `tests/` directory. The tests use mock providers, so they need no cloud credentials. |
| `pr-title.yaml` | Checks that the title is a conventional commit, and that its scope names the one module the PR changes. The title decides the release bump. |
| `terraform-plan-NN.yaml` | Plans each example the PR affects and posts the plan on the PR. |
| `terraform-validate.yaml` | Checks `terraform fmt` across the repo. |
| `terraform-lock.yaml` | When a lock file, a `versions.tf` or `renovate.json` changes, regenerates every `.terraform.lock.hcl` for the five platforms and fails if anything differs. |
| `package-lambdas.yaml` | When Lambda source under `src/` changes, runs its unit tests and builds a reproducible zip. |

## On merge to master

| Workflow | What it does |
|---|---|
| `terraform-apply-NN.yaml` | Applies the plan that was approved on the PR. Example 05 is plan-only and is not applied. |
| `module-release.yaml` | Tags and releases every module the merge changed, as `<module>-vX.Y.Z`. |
| `lambda-release.yaml`, `pipetail-cloud-*-release.yaml` | Release the modules that keep their own version files. |
| `packer-wireguard-04.yaml` | Builds the WireGuard AMI when example 04's Packer files change. It calls the reusable `packer-build.yaml`, which validates on PRs and builds on merge. |

## On a schedule

| Workflow | When | What it does |
|---|---|---|
| `periodic-terraform-apply-NN.yaml` | weekly | Re-applies each live example, which also corrects drift. |
| `update-bottlerocket-ami.yaml` | Mondays 08:00 UTC | Opens a PR when a newer Bottlerocket AMI is published in SSM. |
| `terraform-state-unlock.yaml` | daily 02:00 UTC | Removes S3 state locks older than four hours. It can also be started by hand. |

## pre-commit

Install once with `pre-commit install`. The hooks run on the files each commit changes. The configuration is [`.pre-commit-config.yaml`](../.pre-commit-config.yaml). It covers formatting (`terraform fmt`, `packer fmt`, `shfmt`, `opa fmt`), validation (`terraform validate`, tflint, checkov, the GitHub workflow schemas), the conftest policies and their unit tests, terraform-docs for module READMEs, shellcheck, and the usual file hygiene hooks.

Run everything by hand with `pre-commit run --all-files`.

## Lock files

`.terraform.lock.hcl` is committed and covers five platforms, so the same hashes verify on every laptop and runner:

```
terraform providers lock \
  -platform=windows_amd64 \
  -platform=darwin_amd64 \
  -platform=linux_amd64 \
  -platform=darwin_arm64 \
  -platform=linux_arm64
```

## Renovate

[`renovate.json`](../renovate.json) pins GitHub Actions to digests, groups Terraform provider and module updates, and automerges provider patches and action digests. Lock file maintenance runs weekly. Other repositories can extend it as `github>pipetail/terraform`.

# AGENTS.md

Rules for anyone, human or agent, changing this repo. Each rule below is enforced by CI or by the release process, and the check that enforces it is named.

## Layout

- `modules/<name>/`: reusable modules. Each is released on its own as `<name>-vX.Y.Z`.
- `modules/<name>/tests/*.tftest.hcl`: the module's `terraform test` suite, with mock providers.
- `examples/NN-<name>/`: Terraform roots with their own state. They are planned on PRs and applied on merge, except example 05, which is plan-only.
- `conftest-policies/`: OPA policies with a `_test.rego` next to each one.
- `src/<lambda>/`: Lambda source. It is packaged by `scripts/package-lambdas.sh` and shipped as a GitHub release asset, never committed as a zip.
- `docs/`: how CI, policies and conventions work.

## Never

- Never run `terraform apply`. Merging a PR applies the examples.
- Never change state with CLI commands (`terraform import`, `state mv`, `state rm`, `taint`). Use blocks in `migrations.tf`.
- Never name a customer, or copy an account id, ARN, hostname or CIDR from outside this repo. The repo is public. Use `123456789012`, `example-org/example-repo` and `10.0.0.0/16`.

## Terraform

- State changes go in the root's `migrations.tf` as `moved {}`, `import {}` or `removed {}` blocks. The file only grows. `import {}` blocks are skipped once the resource is in state, so never delete them as done. To change a resource's type, pair `removed { lifecycle { destroy = false } }` with an `import {}` for the new type.
- Write every AWS policy with `jsonencode()`. `conftest-policies/json_policy.rego` rejects `data "aws_iam_policy_document"` and raw JSON heredocs.
- Put a `#checkov:skip=CKV_XXX:reason` inside the resource or module block, after the opening brace. Checkov ignores it above the block.
- Name template files `*.tftpl`.
- After any provider change, regenerate the lock file for all five platforms. `terraform-lock.yaml` fails otherwise:

  ```
  terraform providers lock -platform=windows_amd64 -platform=darwin_amd64 -platform=linux_amd64 -platform=darwin_arm64 -platform=linux_arm64
  ```

## Module changes

- Every behaviour a module promises needs a run in its `tests/` suite. `terraform-test.yaml` runs every suite on each PR, with no cloud credentials.
- A new test must fail on the old code and pass on the new code. Check that before opening the PR.
- Tests read only a module's own resources and its nested modules' outputs. If a value inside a registry module needs a test, expose it as an output first.
- Keep existing callers working. Add a variable whose default keeps today's behaviour, unless today's behaviour is the bug.

## Pull requests

- The title is a Conventional Commit, and its scope names the module the PR changes: `fix(eks): ...`. `pr-title.yaml` rejects any other scope for a single-module PR. Split a PR that touches two modules.
- The squash-merged title decides the release: `fix` is a patch, `feat` a minor, `!` or a `BREAKING CHANGE:` footer a major. `module-release.yaml` cuts the tag. Never edit a version by hand, with three exceptions that have their own release workflows. A change to `pipetail-cloud-role` or `pipetail-cloud-health-ingest` must bump the module's `VERSION` file. A change to the Lambda in `src/aws-events-to-slack/` must bump its `package.json`. Their release workflows fail on an unbumped change.
- Changes to only `.md` files or a module's `tests/` directory are not released.
- Run `pre-commit run --files <changed files>` before pushing. CI runs the same hooks, plus the policies over the whole tree.

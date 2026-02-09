# terraform
This repo is trying to show how we use terraform in [pipetail](https://pipetail.io).

It is for our internal use to reference external terraform modules as well as a "terraform skeleton" to bootstrap new infrastructure.
We also use it for educational purposes as a reference in our workshops.

We hope this will also help to anyone out there searching for some terraform "best practices" and inspiration for "public cloud infrastructure codebases".

You might want to check out [10 most common mistakes using terraform](https://blog.pipetail.io/posts/2020-10-29-most-common-mistakes-terraform/).

Any feedback & contributions are welcome!

## repository layout
For independent terraform states / environments / etc. we use `folder layout` rather than somehow using one folder with `staging.tfvars` and `prod.tfvars` and plenty of `if`s in the configuration.

We prefer boilerplate rather than complexity in this.

Folder layout also makes it easier to use `direnv` with `AWS_PROFILE` credentials and other ENV vars we might need.

## pre-commit
This repository uses pre-commit framework https://pre-commit.com. Please install
the framework and install all the hooks by invoking:

```
pre-commit install
```

The configuration is directly in [.pre-commit-config.yaml](.pre-commit-config.yaml) file. It mainly ensures the following:

- `terraform_fmt` - terraform code formatting
- `terraform_docs` - auto-generated module documentation
- `terraform_validate` - terraform syntax validation
- `terraform_tflint` - terraform linting with custom rules
- `terraform_checkov` - security and compliance scanning
- `shellcheck` / `shfmt` - shell script linting and formatting
- `packer_fmt` - packer file formatting
- `check-merge-conflict` - avoids commiting merge-conflicts by mistake
- `end-of-file-fixer` - convention for end-of-files (empty line at end of every file)
- `trailing-whitespace` - deletes trailing whitespaces at end of lines
- `check-yaml` - validates YAML syntax
- `pretty-format-json` - consistent JSON formatting
- `detect-private-key` - avoids commiting private keys in git
- `check-added-large-files` - avoids commiting large files (>4MB) in git
- `check-case-conflict` - catches filename case conflicts across platforms
- `check-executables-have-shebangs` / `check-shebang-scripts-are-executable` - script permission sanity
- `no-commit-to-branch` - prevents accidental direct commits to `master` and `main`
- `check-github-actions` / `check-github-workflows` - validates GitHub Actions workflow schema

It is possible to manually run all checks on all files using
```
pre-commit run --all-files
```

However, pre-commit hooks are going to run automatically every time you try to `git commit`. The hook will run only on the files that changed within the commit itself, not on all files.

## terraform fmt
Please always run (pre-commit does this for you):

```
terraform fmt -recursive .
```

in the root of your repo.

This command rewrites Terraform configuration files to a canonical format and style.

It's prettier. It doesn't trigger your colleagues' OCDs anymore. Just do it. No arguing.

## .terraform.lock.hcl
We use the [terraform dependency lock file](https://www.terraform.io/language/files/dependency-lock) to track terraform provider dependencies and verify their checksums.

This file is versioned in git and not `.gitignore`d as many people do.

We lock multiple platforms:

```
terraform providers lock  \
  -platform=windows_amd64 \
  -platform=darwin_amd64  \
  -platform=linux_amd64   \
  -platform=darwin_arm64  \
  -platform=linux_arm64
```

The `terraform-lock.yaml` workflow automatically updates lock files when provider versions change in PRs. It runs `terraform providers lock` for all platforms and commits the updated lock files back to the PR branch.

## renovate
We use renovate to manage all our dependencies.

Since we prefer pinning our dependencies to certain versions (as opposed to using something like `:latest`, etc.), we still need an "upgrade strategy". Instead of manually checking for newer versions, changelogs and creating PRs to upgrade each of the dependencies, we have this automated.
That's where renovate comes into play.

Renovate is configured by [`renovate.json`](./renovate.json). Key features of our configuration:

- **GitHub Action digest pinning** for supply chain security
- **Grouped PRs** - Terraform providers and modules are grouped to reduce PR noise
- **Automerge** for low-risk updates (provider patch versions, action digest updates)
- **Custom regex managers** for tracking EKS/Kubernetes versions in Terraform variables
- **Lock file maintenance** scheduled weekly to keep dependency metadata fresh
- **Separate major/minor/patch** updates so breaking changes are clearly visible

Renovate scans all files in default branch and looks for dependencies and their versions. It looks through terraform files, Dockerfiles, etc. and when it finds a new version is available for something, it creates a Pull Request with bumping the version, dumps Changelog, etc.

We run all github actions checks to validate, test and `terraform plan` the changes and when it is safe to upgrade, we simply merge the PR.

The `terraform-lock.yaml` workflow automatically updates lock files when Renovate (or any PR) changes provider versions, since Renovate doesn't handle this natively.

## .gitignore
This `.gitignore` is a template we use in all our git repos where terraform is used.

## GitHub Actions
There are several GitHub Actions workflows:

- `precommit.yaml` - to check everything with pre-commit in Pull Requests since some people might "forget" to use it :))
- `terraform-validate.yaml` - to `terraform validate` everything
- `terraform-plan-*.yaml` - to `terraform plan` all folders in PRs
- `terraform-apply-*.yaml` - to `terraform apply` all approved plans from PRs (approved == merged PR)
- `periodic-terraform-apply-*.yaml` - aka "poor man's gitops" to periodically terraform apply what is in the default branch, can be also triggered manually (useful when terraform-apply workflows fail for issues with previous terraform plans, etc.)
- `terraform-lock.yaml` - automatically updates `.terraform.lock.hcl` files for all platforms when provider versions change in PRs
- `terraform-state-unlock.yaml` - scheduled workflow (daily 2 AM) that detects and removes stale S3 state locks (>4 hours old), also supports manual unlock via workflow_dispatch
- `terraform-drift-detection.yaml` - scheduled workflow (twice daily at 8 AM and 4 PM UTC) that runs `terraform plan` on all environments to detect configuration drift
- `packer-build.yaml` - reusable workflow for building AMIs with Packer
- `packer-wireguard-04.yaml` - builds WireGuard VPN AMI when Packer files change in example 04
- `update-bottlerocket-ami.yaml` - weekly check for new Bottlerocket AMI releases, creates a PR to update the pinned version
- `scheduled-scale-in.yaml.example` / `scheduled-scale-out.yaml.example` - example workflows for scaling down non-prod resources on evenings/weekends and scaling back up on Monday morning
- `package-lambdas.yaml` - automatically packages Lambda functions when source code changes in PRs, commits updated zip files back to the branch
- `lambda-deploy.yaml` - manual workflow dispatch to build, upload, and deploy Lambda functions to S3 and optionally update the function code

All GitHub Actions are pinned to full commit digests (not tags) for supply chain security.

### Drift Detection

The `terraform-drift-detection.yaml` workflow automatically detects when infrastructure has been modified outside of Terraform (e.g., via AWS Console or CLI). This is important because:

- **Unexpected changes**: Someone may have made emergency fixes directly in AWS that need to be captured in code
- **Security**: Unauthorized or accidental changes should be detected and reviewed
- **State consistency**: Drift can cause future `terraform apply` runs to behave unexpectedly

The workflow uses `terraform plan -detailed-exitcode` where exit code 2 indicates drift. When drift is detected:
1. A summary is posted to the GitHub Actions step summary
2. A GitHub issue is automatically created (with label `terraform-drift`) to track resolution
3. The issue links to the workflow run for detailed plan output

The workflow can also be triggered manually via `workflow_dispatch` for on-demand drift checks. Tool versions in CI workflows are explicitly pinned for reproducibility.

### Packer Builds

The `packer-build.yaml` is a reusable workflow for building custom AMIs with Packer. It provides:

- **OIDC authentication** for secure AWS access
- **Validation on PRs** - runs `packer validate` to catch errors before merge
- **Build on merge** - builds the AMI when changes are pushed to master
- **Bot commit detection** - skips builds triggered by automated commits to prevent loops
- **Step summary** - outputs the built AMI ID to GitHub Actions summary

Example 04 (WireGuard VPN) uses this pattern via `packer-wireguard-04.yaml`. To add Packer CI for other examples, create a caller workflow that references the reusable workflow with appropriate inputs.

### Scheduled Scale-In / Scale-Out

The `scheduled-scale-in.yaml.example` and `scheduled-scale-out.yaml.example` workflows demonstrate how to reduce non-production costs by scaling down resources on evenings/weekends and scaling back up before business hours. They use targeted `terraform apply` with variable overrides to adjust Aurora reader replica counts (or any other autoscaling target) on a cron schedule. Copy and customize for your environments.

### Bottlerocket AMI Updates

The `update-bottlerocket-ami.yaml` workflow runs weekly (Monday 8 AM UTC) to check for new [Bottlerocket](https://github.com/bottlerocket-os/bottlerocket) AMI releases. It queries the AWS SSM public parameter for the latest AMI ID, compares it against the version pinned in Terraform, and creates a PR with the updated AMI ID when a new version is available. This ensures EKS nodes run on the latest Bottlerocket release with security patches and bug fixes while still going through the standard PR review and terraform plan process.

### Lambda Deployment

Lambda functions live in `src/<lambda-name>/` directories with an `index.mjs` (or `index.js`) entry point. Two workflows handle the build and deploy lifecycle:

- **`package-lambdas.yaml`** runs automatically on PRs when Lambda source code changes. It uses `scripts/package-lambdas.sh` to create reproducible zip packages (normalized timestamps, deterministic file ordering) and commits the updated `.zip` files back to the PR branch. If the packaging script itself changes, all Lambdas are repackaged.

- **`lambda-deploy.yaml`** is a manual `workflow_dispatch` workflow for deploying a Lambda to a target environment. It packages the function, uploads the zip to an S3 artifacts bucket, and optionally updates the Lambda function code via the AWS CLI. The S3 bucket and region are configurable per invocation.

## tflint

## checkov
[Checkov]() is an amazing tool to lint terraform (and other) resources, we use the non-official pre-commit hook by antonbabenko

## State Locking
We use S3 native locking with `use_lockfile = true` (requires Terraform 1.6+). This eliminates the need for a separate DynamoDB table for state locking.

Example backend configuration:
```hcl
terraform {
  backend "s3" {
    bucket       = "my-terraform-state"
    key          = "infrastructure"
    region       = "eu-west-1"
    use_lockfile = true
    encrypt      = true
  }
}
```

The `aws-bootstrap` module still supports creating a DynamoDB table for backwards compatibility via `create_dynamodb_table = true`, but this is no longer the default.

The `terraform-state-unlock.yaml` workflow runs daily to detect and remove stale locks (locks older than 4 hours are considered stale and are automatically removed). Manual unlock is also available via workflow_dispatch for emergency situations.

## direnv
.envrc in every folder using includes + correct AWS_PROFILE

## tfenv
We use [tfenv](https://github.com/tfutils/tfenv) to manage multiple terraform versions on our local workstations.

## shellcheck
What kind of infra would be it if it's not sprinkled with some shell scripts?

[Shellcheck](https://www.shellcheck.net) is awesome to lint your scripts. That's why we use it in pre-commit.


## terraform-docs
Since we specify variables descriptions and types, it is easy to generate terraform documentation for all our modules:

```
terraform-docs  markdown . > README.md
```

This is useful for some people and takes no effort on our side. We do this manually so far. Automating this and having this in pre-commit would be far better.
I'm writing this here as a TODO.

## naming conventions
Basically just [this](https://www.terraform-best-practices.com/naming)

- `snake_case` in terraform resource names (no convention for cloud resources names, often we use `camel-case`)
- don't repeat resource types in names, `resource "aws_route_table" "public_route_table"` is ugly and long

these are (partially) enforced by `tflint`.

## contributions
special thanks to
- [@vranystepan](https://github.com/vranystepan)
- [@vdovhanych](https://github.com/vdovhanych)

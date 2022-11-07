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

- terraform & shell code formatting
- terraform docs generating
- terraform validation
- terraform linting for security compliance, etc.
- avoids commiting merge-conflicts by mistake
- convention for end-of-files (empty line at each of every file)
- deletes trailing whitespaces at end of lines
- pretty json & yaml formatting
- avoids commiting private keys in git
- avoids commiting large files in git
- etc.

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

## renovate
We use renovate to manage all our dependencies.

Since we prefer pinning our dependencies to certain versions (as opposed to using something like `:latest`, etc.), we still need an "upgrade strategy". Instead of manually checking for newer versions, changelogs and creating PRs to upgrade each of the dependencies, we have this automated.
That's where renovate comes into play.

Renovate is configured by [`renovate.json`](./renovate.json), the configuration we use is rather simple.

Renovate scans all files in default branch and looks for dependencies and their versions. It looks through terraform files, Dockerfiles, etc. and when it finds a new version is available for something, it creates a Pull Request with bumping the version, dumps Changelog, etc.

We run all github actions checks to validate, test and `terraform plan` the changes and when it is safe to upgrade, we simply merge the PR.

Note: one additional github action runs to `terraform lock` to sync the terraform lockfile, since renovate doesn't seem do this.

## .gitignore
This `.gitignore` is a template we use in all our git repos where terraform is used.

## GitHub Actions
There are several GitHub Actions workflows:

- `precommit.yaml` - to check everything with pre-commit in Pull Requests since some people might "forget" to use it :))
- `terraform-validate.yaml` - to `terraform validate` everything
- `terraform-plan-*.yaml` - to `terraform plan` all folders in PRs
- `terraform-apply-*.yaml` - to `terraform apply` all approved plans from PRs (approved == merged PR)
- `periodic-terraform-apply-*.yaml` - aka "poor man's gitops" to periodically terraform apply what is in the default branch, can be also triggered manually (useful when terraform-apply workflows fail for issues with previous terraform plans, etc.)

## tflint

## checkov
[Checkov]() is an amazing tool to lint terraform (and other) resources, we use the non-official pre-commit hook by antonbabenko

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

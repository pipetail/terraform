# Conventions

## One folder per state

Each environment or example is its own folder with its own state. There is no single folder switched between `staging.tfvars` and `prod.tfvars` with conditionals. Some code repeats, and each folder stays simple to read and to plan. Folders also work well with `direnv`: an `.envrc` per folder sets `AWS_PROFILE` and anything else that root needs.

## State locking

The S3 backend locks natively with `use_lockfile = true` (Terraform 1.10 or newer), so no DynamoDB table is needed:

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

`modules/aws-bootstrap` can still create a DynamoDB lock table with `create_dynamodb_table = true`. It is off by default.

## State migrations

Every root keeps its state changes in `migrations.tf` as `moved {}`, `import {}` and `removed {}` blocks, never as `terraform state mv` or `terraform import` commands. A migration then goes through review like any other change, and the apply that follows the merge carries it out.

`migrations.tf` only grows:

- `import {}` blocks are skipped once the resource is in state, so they are safe to keep.
- An applied `moved {}` block does nothing and records the rename.
- To change a resource's type, pair a `removed {}` block that has `destroy = false` with an `import {}` block for the new type.

[`examples/05-aws-complete/migrations.tf`](../examples/05-aws-complete/migrations.tf) shows renames, module extractions, `for_each` key changes and a type change.

## Naming

Names follow [terraform-best-practices.com](https://www.terraform-best-practices.com/naming):

- `snake_case` for Terraform resource names.
- Do not repeat the resource type in its name: `resource "aws_route_table" "public"`, not `"public_route_table"`.

tflint enforces part of this.

## Tools

- [tfenv](https://github.com/tfutils/tfenv) manages Terraform versions on workstations.
- [terraform-docs](https://terraform-docs.io) writes each module's inputs and outputs into its README through pre-commit.
- [shellcheck](https://www.shellcheck.net) lints the shell scripts.

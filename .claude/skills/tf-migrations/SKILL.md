---
name: tf-migrations
description: Use when a Terraform resource must be adopted into state, renamed, re-keyed, moved between files or modules, changed to another resource type, or dropped from state without deleting it, and whenever a change, review or cleanup touches a migrations.tf file or its import, moved or removed blocks. Also when tempted to run terraform import, state mv, state rm or taint.
user-invocable: true
---

# tf-migrations

State changes in this repo are HCL blocks in the root's `migrations.tf`, next to the root's other
`.tf` files. The PR's plan shows what they do, and the apply on merge runs them. Never use the CLI
state commands (`terraform import`, `state mv`, `state rm`, `taint`): they leave no trace in review
and CI does not replay them.

Create `migrations.tf` in the root if it does not have one yet.

## The file only grows

Add blocks. Never edit or delete an existing `import {}`, `moved {}` or `removed {}` block, and never
propose deleting one in a review or a cleanup PR.

"It already ran" is not a reason. An applied block is a no-op, so the plan is identical with or
without it, and a "No changes" plan after deleting one proves nothing. The block is still needed by
any state that has not seen it yet, such as a fresh copy of an example.

If a comment in a `migrations.tf` says applied imports can be removed, this rule wins.

One exception: when you delete a resource from config, also delete any `import {}` whose `to` points
at it. An import with no matching resource fails the plan. Say so in the PR.

## Pick the block

| You want to | Block |
|---|---|
| Bring an existing cloud resource under Terraform | `import {}` |
| Rename an address, re-key a `for_each`, move into or out of a module | `moved {}` |
| Stop managing a resource but keep it in the cloud | `removed {}` with `destroy = false` |
| Change the resource type | `removed {}` with `destroy = false`, plus `import {}` for the new type |

```hcl
import {
  to = aws_s3_bucket.assets
  id = "example-assets-bucket"
}

moved {
  from = aws_s3_bucket.old_name
  to   = aws_s3_bucket.new_name
}

removed {
  from = aws_s3_bucket.assets

  lifecycle {
    destroy = false
  }
}
```

`import {}` blocks are idempotent: Terraform skips one whose resource is already in state. That is why
they stay in the file.

Leave out `destroy = false` only when the apply should delete the real resource.

## Changing a resource's type

`moved {}` only crosses types when the provider supports that move. If the plan rejects it, drop the
old type from state without destroying it and import the same object under the new type, in one PR:

```hcl
removed {
  from = aws_security_group_rule.https

  lifecycle {
    destroy = false
  }
}

import {
  to = aws_vpc_security_group_ingress_rule.https
  id = "sgr-0123456789abcdef0"
}
```

Replace the old `resource` block with the new one in the same commit. The import `id` format differs
per resource type; the provider docs list it under "Import".

## Check the plan

Every example root is planned on the PR, and the plan is posted as a PR comment. Read it before
asking for a merge, because merging applies it:

- a `moved {}` shows the resource "has moved to" its new address, with no destroy and no create
- an `import {}` shows "will be imported", with no diff or only the diff you intended
- a `removed {}` with `destroy = false` shows "will no longer be managed by Terraform", never "will be destroyed"

Any destroy or replace that you did not intend means the block is wrong. Fix it before merge.

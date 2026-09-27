# Policies

## Conftest

[Conftest](https://www.conftest.dev/) policies in [`conftest-policies/`](../conftest-policies) catch mistakes that tflint and checkov do not. Each policy has a `_test.rego` file next to it. CI runs the unit tests and the policies over the whole tree on every PR.

| Policy | Rejects |
|---|---|
| `json_policy.rego` | `data "aws_iam_policy_document"` and raw JSON heredocs in any AWS policy field, including nested and `dynamic` `inline_policy` blocks. Use `jsonencode()`. |
| `provider_version_pinning.rego` | Provider constraints with no upper bound. Pin exactly, use `~>`, or add an upper bound. |
| `s3_lifecycle.rego` | `prefix` as a top-level key in an S3 lifecycle rule. Terraform accepts it, but the rule then applies to every object in the bucket. Put it in a `filter` block. |
| `s3_public_access.rego` | Bucket ACLs other than `private`, and public access blocks with any flag turned off. |
| `security_group_rules.rego` | Security group rules open to `0.0.0.0/0` or `::/0`. |
| `rds_encryption.rego` | RDS instances, clusters and cluster instances without `storage_encrypted`. |
| `dynamodb_encryption.rego` | DynamoDB tables without server-side encryption. It warns when point-in-time recovery or a replica is missing. |

Run them locally:

```bash
conftest verify --policy conftest-policies/
conftest test --parser hcl2 --policy conftest-policies/ modules/kms/main.tf
```

To add a policy, write `deny_` rules in a new `.rego` file, add a `_test.rego` next to it, then run `conftest verify` and `opa fmt -w conftest-policies/`.

## Writing policies in Terraform

Use `jsonencode()` for every AWS policy field: IAM, S3 bucket policies, KMS key policies, SNS and SQS policies, ECR repository policies and the rest. The policy then sits with its resource, and the plan shows a clean diff.

```hcl
resource "aws_iam_policy" "example" {
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject"]
      Resource = ["arn:aws:s3:::bucket/*"]
    }]
  })
}
```

## tflint and checkov

[tflint](https://github.com/terraform-linters/tflint) runs with the AWS ruleset, configured in [`.tflint.hcl`](../.tflint.hcl). [Checkov](https://www.checkov.io) runs through pre-commit. A checkov skip goes inside the resource or module block, after the opening brace, with a reason:

```hcl
resource "aws_cloudwatch_log_group" "example" {
  #checkov:skip=CKV_AWS_338:Retention is configured per environment via variable
  name = "example"
}
```

## Detection is out of scope

The examples cover the logging layer: CloudTrail, VPC flow logs, ALB access logs, RDS log exports, and KMS-encrypted log groups with retention. They do not set up GuardDuty, AWS Config or Security Hub. Those services are priced on volume, and the right setting depends on the account. Anything built from these examples should add detection sized for the account it runs in.

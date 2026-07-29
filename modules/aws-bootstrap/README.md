# aws-bootstrap

Creates the S3 bucket that holds Terraform state for an account, and optionally the
DynamoDB table used for state locking. This is the first thing applied in a new account,
before any workspace has a remote backend to write to.

The bucket is versioned, encrypted, has all four public-access blocks on, and carries a
policy denying non-TLS requests.

## Bootstrapping order

The module has to run before the backend it creates exists, so apply it with local state
first, then add the backend block and re-run to migrate:

```hcl
module "bootstrap" {
  source = "github.com/pipetail/terraform//modules/aws-bootstrap"

  region      = "eu-west-1"
  name_prefix = "my-account"
}
```

```console
terraform init && terraform apply     # local state
# add the backend block below, then:
terraform init -migrate-state
```

```hcl
terraform {
  backend "s3" {
    bucket       = "my-account-tf-state-eu-west-1"
    key          = "infrastructure"
    region       = "eu-west-1"
    use_lockfile = true
    encrypt      = true
  }
}
```

Keep the bootstrap workspace's own state local (or in a separate bucket) if you want the
bucket to remain destroyable without the state that manages it living inside it.

## Bucket naming

The bucket is named `${name_prefix}-${bucket_purpose}-${region}`. S3 bucket names are a
single global namespace, so a generic `name_prefix` can collide with a bucket owned by
someone else entirely and fail the apply with `BucketAlreadyExists`. Pick something
account-specific.

## State locking

S3 native locking (`use_lockfile = true`, Terraform 1.6+) is the default path and needs no
table — `create_dynamodb_table` is `false`. Set it to `true` only for backends still using
`dynamodb_table`. The default table name is not prefixed, so two bootstrapped stacks in the
same account and region will fight over `terraform-state-lock` unless you override
`dynamodb_table_name`.

## Destroying

`state_bucket_force_destroy` is off by default. Turning it on lets `terraform destroy`
delete the bucket along with every object version in it, which includes every historical
copy of the state — versioning stops being a recovery path. Leave it off unless the bucket
is genuinely disposable.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.83 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.83 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_terraform_state"></a> [terraform\_state](#module\_terraform\_state) | terraform-aws-modules/s3-bucket/aws | 4.11.0 |

## Resources

| Name | Type |
|------|------|
| [aws_dynamodb_table.terraform_state_lock](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_bucket_purpose"></a> [bucket\_purpose](#input\_bucket\_purpose) | Name to identify the bucket's purpose | `string` | `"tf-state"` | no |
| <a name="input_create_dynamodb_table"></a> [create\_dynamodb\_table](#input\_create\_dynamodb\_table) | Create DynamoDB table for Terraform state locking. Not needed when using S3 native locking (use\_lockfile = true in backend config, requires Terraform 1.6+). | `bool` | `false` | no |
| <a name="input_dynamodb_point_in_time_recovery"></a> [dynamodb\_point\_in\_time\_recovery](#input\_dynamodb\_point\_in\_time\_recovery) | Point-in-time recovery options | `bool` | `false` | no |
| <a name="input_dynamodb_table_name"></a> [dynamodb\_table\_name](#input\_dynamodb\_table\_name) | Name of the DynamoDB Table for locking Terraform state. | `string` | `"terraform-state-lock"` | no |
| <a name="input_dynamodb_table_tags"></a> [dynamodb\_table\_tags](#input\_dynamodb\_table\_tags) | Tags of the DynamoDB Table for locking Terraform state. | `map(string)` | <pre>{<br/>  "Automation": "Terraform",<br/>  "Name": "terraform-state-lock"<br/>}</pre> | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Used as a name prefix for resources | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | AWS region. | `string` | n/a | yes |
| <a name="input_state_bucket_force_destroy"></a> [state\_bucket\_force\_destroy](#input\_state\_bucket\_force\_destroy) | Allow destroying the state bucket while it still holds objects. A destroy then removes every object version along with the bucket, so versioning does not keep the Terraform state recoverable. Leave disabled unless the bucket is genuinely disposable. | `bool` | `false` | no |
| <a name="input_state_bucket_kms_key_id"></a> [state\_bucket\_kms\_key\_id](#input\_state\_bucket\_kms\_key\_id) | KMS key ID, ARN or alias used to encrypt the state bucket with SSE-KMS. Leave null to keep SSE-S3 (AES256). Every principal that runs Terraform against this backend needs kms:Decrypt and kms:GenerateDataKey on the key, so grant that before pointing an existing bucket at a key, otherwise state reads start failing. | `string` | `null` | no |
| <a name="input_state_bucket_logging"></a> [state\_bucket\_logging](#input\_state\_bucket\_logging) | S3 server access logging for the state bucket, e.g. { target\_bucket = "my-log-bucket", target\_prefix = "tf-state/" }. The target bucket must already exist and allow log delivery. Empty map leaves access logging off. | `map(string)` | `{}` | no |
| <a name="input_state_bucket_tags"></a> [state\_bucket\_tags](#input\_state\_bucket\_tags) | Tags to associate with the bucket storing the Terraform state files | `map(string)` | <pre>{<br/>  "Automation": "Terraform"<br/>}</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_dynamodb_table"></a> [dynamodb\_table](#output\_dynamodb\_table) | The name of the dynamo db table |
| <a name="output_region"></a> [region](#output\_region) | AWS region the state bucket lives in, for the backend block |
| <a name="output_state_bucket"></a> [state\_bucket](#output\_state\_bucket) | The state\_bucket name |
| <a name="output_state_bucket_arn"></a> [state\_bucket\_arn](#output\_state\_bucket\_arn) | ARN of the bucket storing the Terraform state files |
<!-- END_TF_DOCS -->

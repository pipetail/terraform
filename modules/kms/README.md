# kms

Creates one customer-managed KMS key, with automatic rotation on, for encrypting resources such
as RDS, EBS, EKS secrets, CloudWatch Logs and CloudTrail in one account. The key policy is built
from ARN lists: administrators, IAM principals allowed to use the key, CloudWatch Logs log groups
in `region`, and CloudTrail trails. The policy has no account-root statement, so include the role
that runs Terraform in `key_administrator_arns` or it cannot manage the key after creation. The
key has `prevent_destroy` set, so Terraform refuses any plan that would delete or replace it.

## Usage

```hcl
module "kms" {
  source = "github.com/pipetail/terraform//modules/kms?ref=kms-v1.0.0"

  region                 = "eu-west-1"
  key_administrator_arns = ["arn:aws:iam::123456789012:role/terraform"]
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.57.0, < 7.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 4.57.0, < 7.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_kms_key.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cloudtrail_trail_arns"></a> [cloudtrail\_trail\_arns](#input\_cloudtrail\_trail\_arns) | CloudTrail trail ARNs allowed to use the KMS key | `set(string)` | `[]` | no |
| <a name="input_cloudwatch_log_group_arn_patterns"></a> [cloudwatch\_log\_group\_arn\_patterns](#input\_cloudwatch\_log\_group\_arn\_patterns) | CloudWatch Logs log group ARN patterns allowed to use the KMS key | `set(string)` | `[]` | no |
| <a name="input_deletion_window_in_days"></a> [deletion\_window\_in\_days](#input\_deletion\_window\_in\_days) | Duration in days after which the key is deleted after destruction | `number` | `10` | no |
| <a name="input_key_administrator_arns"></a> [key\_administrator\_arns](#input\_key\_administrator\_arns) | IAM role or user ARNs allowed to administer the KMS key | `set(string)` | n/a | yes |
| <a name="input_key_rotation_enabled"></a> [key\_rotation\_enabled](#input\_key\_rotation\_enabled) | Enable automatic key rotation | `bool` | `true` | no |
| <a name="input_key_user_arns"></a> [key\_user\_arns](#input\_key\_user\_arns) | IAM role or user ARNs allowed to use the KMS key | `set(string)` | `[]` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS region name for the KMS key | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_kms_key"></a> [kms\_key](#output\_kms\_key) | KMS key resource |
| <a name="output_kms_key_arn"></a> [kms\_key\_arn](#output\_kms\_key\_arn) | KMS key ARN |
| <a name="output_kms_key_id"></a> [kms\_key\_id](#output\_kms\_key\_id) | KMS key ID |
<!-- END_TF_DOCS -->

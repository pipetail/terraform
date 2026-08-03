# pipetail-cloud-role

Creates the read-only IAM role that [pipetail.cloud](https://pipetail.cloud) assumes to
inspect an AWS account. The role grants exactly the actions the scan services call and is
bound to the external ID the portal minted for the connection, so no other principal in the
portal's AWS account can use it.

This is the Terraform equivalent of the CloudFormation template the portal's Connect account
flow offers. Use whichever fits — the resulting role is the same.

## One role per account

The role name is account-unique. An AWS account connected to the portal needs exactly one
instance of this module, even when several Terraform roots manage that same account.

Every connected account gets its own external ID. Do not reuse one account's external ID for
another: the portal validates the connection by assuming the role with the ID it minted, and
a mismatch fails the assume.

## Usage

```hcl
module "pipetail_cloud_role" {
  source = "github.com/pipetail/terraform//modules/pipetail-cloud-role?ref=pipetail-cloud-role-v1.0.0"

  external_id = "the-external-id-from-the-portal"
}

output "pipetail_cloud_role_arn" {
  value = module.pipetail_cloud_role.role_arn
}
```

Apply, then paste the `role_arn` output into the portal to complete the connection.

## Cost

All granted actions are free management-plane reads except the two Cost Explorer
recommendation calls (`ce:GetReservationPurchaseRecommendation`,
`ce:GetSavingsPlansPurchaseRecommendation`) and `ce:GetAnomalyMonitors`, which the
[Cost Explorer API prices per request](https://aws.amazon.com/aws-cost-management/aws-cost-explorer/pricing/).
The portal calls them once per scan.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.0.0, < 7.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.57.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_iam_role.pipetail_cloud](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.scan_read](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_external_id"></a> [external\_id](#input\_external\_id) | External ID minted by pipetail.cloud for this account connection. Unique per connected account — copy it from the portal's Connect account flow. | `string` | n/a | yes |
| <a name="input_portal_aws_account_id"></a> [portal\_aws\_account\_id](#input\_portal\_aws\_account\_id) | AWS account ID pipetail.cloud assumes this role from | `string` | `"680177765279"` | no |
| <a name="input_role_name"></a> [role\_name](#input\_role\_name) | Name of the IAM role to create | `string` | `"pipetailCloud"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to the IAM role | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_role_arn"></a> [role\_arn](#output\_role\_arn) | ARN of the created role — paste this into pipetail.cloud to complete the connection |
| <a name="output_role_name"></a> [role\_name](#output\_role\_name) | Name of the created role |
<!-- END_TF_DOCS -->

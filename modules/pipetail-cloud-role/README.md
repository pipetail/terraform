# pipetail-cloud-role

Creates the read-only IAM role that pipetail.cloud assumes to scan an AWS account. The role
trusts the pipetail.cloud AWS account only when the call carries the external ID the portal
generated for this connection, and its inline policy lists the Describe, List and Get actions
the scans call instead of the AWS-managed SecurityAudit policy. After apply, paste the `role_arn`
output into pipetail.cloud. The Cost Explorer calls the scans make through this role are billed
per request to the scanned account. API Gateway reads are limited to the REST API list and its
stages, because `apigateway:GET` on every path would also return API key values.

## Usage

```hcl
module "pipetail_cloud_role" {
  source = "github.com/pipetail/terraform//modules/pipetail-cloud-role?ref=pipetail-cloud-role-v2.4.0"

  external_id = "example-external-id"
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.0.0, < 7.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 4.0.0, < 7.0.0 |

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

# pipetail-investigation-role

Creates a read-only IAM role that one pipetail IAM role assumes to investigate an AWS account.
The role has the AWS managed `ReadOnlyAccess` policy attached, plus an inline Deny for the reads
that return stored data: S3 objects, SSM parameter and Secrets Manager values, KMS decrypt,
Lambda, CodeBuild, AppConfig and Amplify configuration, CodeBuild build environments, Lambda
layer archives, EC2 passwords, console output and instance user data, database and table items,
queue and stream messages, Step Functions execution payloads, container images, CodeCommit
content, API Gateway API key values, Cognito user records and Bedrock retrieval and agent memory
content. It also denies role chaining, federation tokens, SSM sessions and commands, and the EKS
Kubernetes API. CloudWatch Logs reads stay allowed.

The trust policy names a single role ARN and requires the session name `gate-host-agent`, so
every call shows up under that name in CloudTrail. AWS adds actions to `ReadOnlyAccess` over
time, and a new action that reads data stays allowed until it is added to the Deny.
`lambda:ListFunctions` and `ecs:DescribeTaskDefinition` return environment variables, and
`ec2:DescribeLaunchTemplateVersions` returns launch template user data. They stay allowed,
because denying them removes the inventory reads.

## Usage

```hcl
module "pipetail_investigation_role" {
  source = "github.com/pipetail/terraform//modules/pipetail-investigation-role?ref=pipetail-investigation-role-v1.0.0"
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.2.0 |
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
| [aws_iam_role.investigation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.deny_data_reads](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.read_only](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_principal_arn"></a> [principal\_arn](#input\_principal\_arn) | ARN of the IAM role allowed to assume this role | `string` | `"arn:aws:iam::680177765279:role/gate-host-agent"` | no |
| <a name="input_role_name"></a> [role\_name](#input\_role\_name) | Name of the IAM role to create | `string` | `"pipetailInvestigation"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to the IAM role | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_role_arn"></a> [role\_arn](#output\_role\_arn) | ARN of the created role |
<!-- END_TF_DOCS -->

# github-oidc

Creates the GitHub Actions OIDC identity provider in an AWS account and an IAM role that
workflows from one repository can assume with `aws-actions/configure-aws-credentials`, so CI
needs no long-lived access keys. By default only runs on the `master` branch can assume the role;
pull requests, environments and other branches have to be listed in `allowed_subjects`, which
are matched exactly. Grant permissions with `managed_policy_arns`, or attach your own policy to
the role named in the `role_name` output. The module always creates the identity provider, and
an account holds only one provider per URL, so use one instance per account.

## Usage

```hcl
module "github_oidc" {
  source = "github.com/pipetail/terraform//modules/github-oidc?ref=github-oidc-v1.0.0"

  repository_name = "example-org/example-repo"
}
```

## Example

[examples/03-aws-github-actions-oidc](../../examples/03-aws-github-actions-oidc) creates the role
for pushes to `master` and pull requests, and attaches a custom policy for pushing to ECR.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.0.0, < 7.0.0 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | >= 4.0.0, < 5.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 4.0.0, < 7.0.0 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | >= 4.0.0, < 5.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_iam_openid_connect_provider.github](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider) | resource |
| [aws_iam_role.github_actions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.github_actions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [tls_certificate.token](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/data-sources/certificate) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allowed_subjects"></a> [allowed\_subjects](#input\_allowed\_subjects) | Exact OIDC `sub` claims allowed to assume the role, e.g. `repo:org/repo:ref:refs/heads/master`, `repo:org/repo:pull_request`, `repo:org/repo:environment:prod`. Matched with StringEquals, so wildcards are not honoured. Defaults to the repository's master branch only. | `list(string)` | `null` | no |
| <a name="input_managed_policy_arns"></a> [managed\_policy\_arns](#input\_managed\_policy\_arns) | IAM Managed Policy ARNs to be attached to the created IAM Role | `list(any)` | `[]` | no |
| <a name="input_repository_name"></a> [repository\_name](#input\_repository\_name) | Github org and repository name (full path) to be allowed in OIDC | `string` | `""` | no |
| <a name="input_role_name"></a> [role\_name](#input\_role\_name) | IAM Role name to be created | `string` | `"github_actions"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_oidc_provider_arn"></a> [oidc\_provider\_arn](#output\_oidc\_provider\_arn) | OIDC Provider ARN |
| <a name="output_role_arn"></a> [role\_arn](#output\_role\_arn) | Github Actions IAM Role ARN |
| <a name="output_role_name"></a> [role\_name](#output\_role\_name) | Github Actions IAM Role name |
<!-- END_TF_DOCS -->

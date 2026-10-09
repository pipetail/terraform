# cluster-autoscaler

Installs the Kubernetes cluster-autoscaler Helm chart into an EKS cluster and creates the IAM
role its service account assumes through the cluster's OIDC provider (IRSA). The role can read
every Auto Scaling group in the account, but can change capacity or terminate instances only in
groups tagged `k8s.io/cluster-autoscaler/<cluster_name> = owned`. The OIDC provider for
`cluster_oidc_issuer_url` must already exist in the account, and the calling configuration needs
a `helm` provider connected to the cluster.

## Usage

```hcl
module "cluster_autoscaler" {
  source = "github.com/pipetail/terraform//modules/cluster-autoscaler?ref=cluster-autoscaler-v1.0.0"

  cluster_name            = "example"
  cluster_oidc_issuer_url = "https://oidc.eks.eu-west-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE"
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0.0, < 7.0.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | < 4.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.0.0, < 7.0.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | < 4.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_iam_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [helm_release.this](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_atomic"></a> [atomic](#input\_atomic) | If set, installation process purges chart on fail. The wait flag will be set automatically if atomic is used. | `bool` | `true` | no |
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | get the version here https://artifacthub.io/packages/helm/cluster-autoscaler/cluster-autoscaler | `string` | `"9.10.7"` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | EKS cluster name | `string` | n/a | yes |
| <a name="input_cluster_oidc_issuer_url"></a> [cluster\_oidc\_issuer\_url](#input\_cluster\_oidc\_issuer\_url) | EKS cluster oidc issuer url | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Helm release name | `string` | `"cluster-autoscaler"` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | name prefix for unique resource names | `string` | `""` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | kubernetes namespace to deploy to | `string` | `"cluster-autoscaler"` | no |
| <a name="input_wait"></a> [wait](#input\_wait) | Will wait until all resources are in a ready state before marking the release as successful. It will wait for as long as timeout. | `bool` | `true` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->

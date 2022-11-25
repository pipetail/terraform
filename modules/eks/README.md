## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.13.0 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | ~> 4.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 4.13.0 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | 3.3.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_eks"></a> [eks](#module\_eks) | terraform-aws-modules/eks/aws | 17.18.0 |

## Resources

| Name | Type |
|------|------|
| [aws_iam_openid_connect_provider.eks](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider) | resource |
| [aws_iam_role_policy_attachment.ssm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_kms_alias.secrets_encryption](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_security_group_rule.ingress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_ami.bottlerocket_ami](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_eks_cluster.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster) | data source |
| [aws_eks_cluster_auth.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster_auth) | data source |
| [aws_iam_policy.ssm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [tls_certificate.cluster](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/data-sources/certificate) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allow_ingress"></a> [allow\_ingress](#input\_allow\_ingress) | ingress to k8s nodes to be allowed | <pre>map(object({<br>    source_security_group_id = string<br>    port                     = number<br>    protocol                 = string<br>  }))</pre> | `{}` | no |
| <a name="input_control_plane_subnets"></a> [control\_plane\_subnets](#input\_control\_plane\_subnets) | AWS VPC subnets for the EKS control plane | `list(string)` | n/a | yes |
| <a name="input_k8s_architecture"></a> [k8s\_architecture](#input\_k8s\_architecture) | cpu architecture to use with k8s nodes | `string` | `"x86_64"` | no |
| <a name="input_k8s_version"></a> [k8s\_version](#input\_k8s\_version) | EKS / Kubernetes version | `string` | `"1.22"` | no |
| <a name="input_map_roles"></a> [map\_roles](#input\_map\_roles) | additional roles that should be mapped to aws-auth config map | `list(any)` | `[]` | no |
| <a name="input_map_users"></a> [map\_users](#input\_map\_users) | additional users that should be mapped to aws-auth config map | `list(any)` | `[]` | no |
| <a name="input_name"></a> [name](#input\_name) | EKS cluster name | `string` | n/a | yes |
| <a name="input_secrets_encryption_kms_key_arn"></a> [secrets\_encryption\_kms\_key\_arn](#input\_secrets\_encryption\_kms\_key\_arn) | KMS Key ARN for k8s secrets encryption | `string` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | ID of VPC where EKS cluster should belong to | `string` | n/a | yes |
| <a name="input_worker_groups"></a> [worker\_groups](#input\_worker\_groups) | k8s worker groups configuration | <pre>list(object({<br>    name              = string<br>    instance_type     = string<br>    asg_max_size      = number<br>    asg_min_size      = number<br>    target_group_arns = list(string)<br>    subnets           = list(string)<br>    set_taint         = bool // automatically add a taint with the nodepool name<br>    max_pods          = number<br>    market_type       = string<br>  }))</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_certificate_authority_data"></a> [cluster\_certificate\_authority\_data](#output\_cluster\_certificate\_authority\_data) | The base64 encoded certificate data required to communicate with your cluster |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | EKS Cluster name |
| <a name="output_cluster_oidc_issuer_url"></a> [cluster\_oidc\_issuer\_url](#output\_cluster\_oidc\_issuer\_url) | EKS OIDC issues url |
| <a name="output_endpoint"></a> [endpoint](#output\_endpoint) | EKS cluster endpoint |
| <a name="output_oidc_provider_arn"></a> [oidc\_provider\_arn](#output\_oidc\_provider\_arn) | EKS OIDC provider ARN |
| <a name="output_token"></a> [token](#output\_token) | EKS cluster token |
| <a name="output_worker_security_group_id"></a> [worker\_security\_group\_id](#output\_worker\_security\_group\_id) | Kubernetes workers VPC Security group ID |

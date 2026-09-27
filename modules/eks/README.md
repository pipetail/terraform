# eks

Creates an EKS cluster through the upstream `terraform-aws-modules/eks/aws` module, with one
managed node group per entry in `worker_groups` running Bottlerocket from the AMI you pass in
`worker_ami_id`. It installs the coredns, kube-proxy, vpc-cni and EBS CSI driver addons, gives the
EBS CSI controller its own IRSA role, and encrypts Kubernetes secrets with the KMS key in
`secrets_encryption_kms_key_arn`. Access uses EKS access entries and gives the identity that applies
Terraform cluster admin, and the public API endpoint is open to `0.0.0.0/0` unless you set
`endpoint_public_access_cidrs`.

## Usage

```hcl
module "eks" {
  source = "github.com/pipetail/terraform//modules/eks?ref=eks-v1.0.0"

  name                           = "example"
  vpc_id                         = "vpc-0123456789abcdef0"
  control_plane_subnets          = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
  secrets_encryption_kms_key_arn = "arn:aws:kms:eu-west-1:123456789012:key/00000000-0000-0000-0000-000000000000"
  worker_ami_id                  = "ami-0123456789abcdef0"

  worker_groups = [
    {
      name              = "main"
      instance_type     = "m7i.large"
      asg_min_size      = 1
      asg_max_size      = 3
      subnets           = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
      target_group_arns = []
      set_taint         = false
      capacity_type     = "ON_DEMAND"
    }
  ]
}
```

## Example

[examples/05-aws-complete](../../examples/05-aws-complete/eks.tf) runs an arm64 cluster behind an
ALB with an administrator access entry.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.7 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0.0, < 7.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.0.0, < 7.0.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_ebs_csi_irsa"></a> [ebs\_csi\_irsa](#module\_ebs\_csi\_irsa) | terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts | 6.8.0 |
| <a name="module_eks"></a> [eks](#module\_eks) | terraform-aws-modules/eks/aws | 21.24.2 |

## Resources

| Name | Type |
|------|------|
| [aws_autoscaling_attachment.node_target_groups](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_attachment) | resource |
| [aws_eks_addon.ebs_csi](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_addon) | resource |
| [aws_kms_alias.secrets_encryption](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_security_group_rule.eks_workers_to_eks_workers_all](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.ingress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_eks_addon_version.coredns](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_addon_version) | data source |
| [aws_eks_addon_version.ebs_csi_driver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_addon_version) | data source |
| [aws_eks_addon_version.kube_proxy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_addon_version) | data source |
| [aws_eks_addon_version.vpc_cni](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_addon_version) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_access_entries"></a> [access\_entries](#input\_access\_entries) | Map of EKS access entries to create (principal\_arn + policy\_associations) | `any` | `{}` | no |
| <a name="input_allow_ingress"></a> [allow\_ingress](#input\_allow\_ingress) | ingress to k8s nodes to be allowed | <pre>map(object({<br/>    source_security_group_id = string<br/>    port                     = number<br/>    protocol                 = string<br/>  }))</pre> | `{}` | no |
| <a name="input_control_plane_subnets"></a> [control\_plane\_subnets](#input\_control\_plane\_subnets) | AWS VPC subnets for the EKS control plane | `list(string)` | n/a | yes |
| <a name="input_endpoint_public_access_cidrs"></a> [endpoint\_public\_access\_cidrs](#input\_endpoint\_public\_access\_cidrs) | CIDRs allowed to reach the public Kubernetes API endpoint. Leave null to inherit the upstream default of 0.0.0.0/0. Set this to the egress addresses that actually need API access — anything running Terraform or kubectl against the cluster must be covered, including CI. | `list(string)` | `null` | no |
| <a name="input_k8s_addon_version"></a> [k8s\_addon\_version](#input\_k8s\_addon\_version) | EKS addons version | `string` | `"1.36"` | no |
| <a name="input_k8s_architecture"></a> [k8s\_architecture](#input\_k8s\_architecture) | cpu architecture to use with k8s nodes | `string` | `"x86_64"` | no |
| <a name="input_k8s_version"></a> [k8s\_version](#input\_k8s\_version) | EKS / Kubernetes version | `string` | `"1.36"` | no |
| <a name="input_kms_key_administrators"></a> [kms\_key\_administrators](#input\_kms\_key\_administrators) | KMS key administrators | `list(string)` | `[]` | no |
| <a name="input_name"></a> [name](#input\_name) | EKS cluster name | `string` | n/a | yes |
| <a name="input_secrets_encryption_kms_key_arn"></a> [secrets\_encryption\_kms\_key\_arn](#input\_secrets\_encryption\_kms\_key\_arn) | KMS Key ARN for k8s secrets encryption | `string` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | ID of VPC where EKS cluster should belong to | `string` | n/a | yes |
| <a name="input_worker_ami_id"></a> [worker\_ami\_id](#input\_worker\_ami\_id) | Bottlerocket AMI ID to use for the k8s worker nodes, must match k8s\_version and k8s\_architecture | `string` | n/a | yes |
| <a name="input_worker_groups"></a> [worker\_groups](#input\_worker\_groups) | k8s worker groups configuration | <pre>list(object({<br/>    name              = string<br/>    instance_type     = string<br/>    asg_max_size      = number<br/>    asg_min_size      = number<br/>    target_group_arns = list(string)<br/>    subnets           = list(string)<br/>    set_taint         = bool // automatically add a taint with the nodepool name<br/>    capacity_type     = string<br/>  }))</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_certificate_authority_data"></a> [cluster\_certificate\_authority\_data](#output\_cluster\_certificate\_authority\_data) | EKS Cluster Cert Auth data |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | EKS Cluster name |
| <a name="output_cluster_oidc_issuer_url"></a> [cluster\_oidc\_issuer\_url](#output\_cluster\_oidc\_issuer\_url) | EKS OIDC issuer url |
| <a name="output_endpoint"></a> [endpoint](#output\_endpoint) | EKS cluster endpoint |
| <a name="output_oidc_provider"></a> [oidc\_provider](#output\_oidc\_provider) | EKS OIDC issuer id |
| <a name="output_oidc_provider_arn"></a> [oidc\_provider\_arn](#output\_oidc\_provider\_arn) | EKS OIDC provider ARN |
| <a name="output_worker_security_group_id"></a> [worker\_security\_group\_id](#output\_worker\_security\_group\_id) | Kubernetes workers VPC Security group ID |
<!-- END_TF_DOCS -->

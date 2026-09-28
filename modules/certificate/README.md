# certificate

Requests an ACM certificate for `domain_name` and any `subject_alternative_names` with DNS
validation, writes the validation records into a Route 53 hosted zone, and waits until the
certificate is issued. It requests the same certificate a second time through the `aws.virginia`
provider, which must point at us-east-1, for services such as CloudFront that only accept
certificates from that Region. ACM gives both copies the same validation records, so the module
waits on the us-east-1 copy as well, and `virginia_certificate_arn` is known only once it is issued.

## Usage

```hcl
module "certificate" {
  source = "github.com/pipetail/terraform//modules/certificate?ref=certificate-v1.0.0"

  providers = {
    aws          = aws
    aws.virginia = aws.virginia
  }

  zone_id     = "Z0123456789EXAMPLE"
  domain_name = "example.com"
}
```

## Example

[examples/05-aws-complete](../../examples/05-aws-complete/certificates.tf) requests a wildcard
certificate for its hosted zone with this module.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.0, < 7.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 4.0, < 7.0.0 |
| <a name="provider_aws.virginia"></a> [aws.virginia](#provider\_aws.virginia) | >= 4.0, < 7.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_acm_certificate.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate.virginia](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate_validation.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation) | resource |
| [aws_acm_certificate_validation.virginia](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation) | resource |
| [aws_route53_record.validation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_domain_name"></a> [domain\_name](#input\_domain\_name) | domain\_name to be used with the certificate | `string` | n/a | yes |
| <a name="input_subject_alternative_names"></a> [subject\_alternative\_names](#input\_subject\_alternative\_names) | Set of domains that should be SANs in the issued certificate | `list(string)` | `[]` | no |
| <a name="input_ttl"></a> [ttl](#input\_ttl) | TTL for the DNS record | `number` | `60` | no |
| <a name="input_zone_id"></a> [zone\_id](#input\_zone\_id) | Route53 zone id | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_certificate_arn"></a> [certificate\_arn](#output\_certificate\_arn) | ACM certificate ARN |
| <a name="output_virginia_certificate_arn"></a> [virginia\_certificate\_arn](#output\_virginia\_certificate\_arn) | ARN of the us-east-1 copy of the ACM certificate, for CloudFront |
<!-- END_TF_DOCS -->

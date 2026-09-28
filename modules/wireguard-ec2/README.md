# wireguard-ec2

Runs a WireGuard VPN server on a single t2.micro EC2 instance with a public IP, and a security
group that opens the WireGuard UDP port to the internet and allows all egress so the host can
route client traffic out. The AMI has to be built with the Packer template under
`examples/04-aws-wireguard-vpn/packer`, and the instance profile and user data you pass let the
host fetch its WireGuard private key from Secrets Manager at boot. Use it when a small VPN into
a VPC is enough and a managed Client VPN endpoint is not needed.

## Usage

```hcl
module "wireguard" {
  source = "github.com/pipetail/terraform//modules/wireguard-ec2?ref=wireguard-ec2-v1.0.1"

  vpc_id               = "vpc-0123456789abcdef0"
  subnet_id            = "subnet-0123456789abcdef0"
  port                 = 51820
  ami_id               = "ami-0123456789abcdef0"
  iam_instance_profile = "example-wireguard"
  user_data            = file("${path.module}/wireguard-user-data.sh")
}
```

## Example

[examples/04-aws-wireguard-vpn](../../examples/04-aws-wireguard-vpn) builds the AMI with Packer,
creates the instance profile and Secrets Manager access, and renders the user data.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.37.0, < 7.0.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_ec2_instance"></a> [ec2\_instance](#module\_ec2\_instance) | terraform-aws-modules/ec2-instance/aws | ~> 6.0 |
| <a name="module_sg"></a> [sg](#module\_sg) | terraform-aws-modules/security-group/aws | 6.0.0 |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_ami_id"></a> [ami\_id](#input\_ami\_id) | AMI ID to be used with the EC2 instance. Build it with the Packer template under examples/04-aws-wireguard-vpn/packer; a stock image carries no WireGuard and the instance would come up as a bare host on a public IP. | `string` | n/a | yes |
| <a name="input_create_instance"></a> [create\_instance](#input\_create\_instance) | Whether or not to create an EC2 instance to run the wireguard | `bool` | `true` | no |
| <a name="input_iam_instance_profile"></a> [iam\_instance\_profile](#input\_iam\_instance\_profile) | IAM instance profile that lets the WireGuard host retrieve its runtime configuration | `string` | n/a | yes |
| <a name="input_port"></a> [port](#input\_port) | wireguard UDP port | `number` | n/a | yes |
| <a name="input_ssh_key_name"></a> [ssh\_key\_name](#input\_ssh\_key\_name) | SSH key name to be used with the EC2 instance | `string` | `""` | no |
| <a name="input_subnet_id"></a> [subnet\_id](#input\_subnet\_id) | VPC Subnet ID to be used with the AWS resources, mainly EC2 instance | `string` | n/a | yes |
| <a name="input_user_data"></a> [user\_data](#input\_user\_data) | Non-secret boot configuration for the WireGuard host | `string` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | ID of the VPC where to create all the resources | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_public_ip"></a> [public\_ip](#output\_public\_ip) | wireguard EC2 instance public IP to be used in VPN config |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | main Security Group ID |
<!-- END_TF_DOCS -->

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_ec2_instance"></a> [ec2\_instance](#module\_ec2\_instance) | terraform-aws-modules/ec2-instance/aws | ~> 4.0 |
| <a name="module_sg"></a> [sg](#module\_sg) | terraform-aws-modules/security-group/aws | 4.13.0 |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_ami_id"></a> [ami\_id](#input\_ami\_id) | AMI ID to be used with the EC2 instance | `string` | `"ami-08ca3fed11864d6bb"` | no |
| <a name="input_create_instance"></a> [create\_instance](#input\_create\_instance) | Whether or not to create an EC2 instance to run the wireguard | `bool` | `true` | no |
| <a name="input_port"></a> [port](#input\_port) | wireguard UDP port | `number` | n/a | yes |
| <a name="input_ssh_key_name"></a> [ssh\_key\_name](#input\_ssh\_key\_name) | SSH key name to be used with the EC2 instance | `string` | `""` | no |
| <a name="input_subnet_id"></a> [subnet\_id](#input\_subnet\_id) | VPC Subnet ID to be used with the AWS resources, mainly EC2 instance | `string` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | ID of the VPC where to create all the resources | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_public_ip"></a> [public\_ip](#output\_public\_ip) | wireguard EC2 instance public IP to be used in VPN config |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | main Security Group ID |

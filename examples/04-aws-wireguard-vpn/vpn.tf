locals {
  dns_zone_suffix = "example.org"
  use_dns         = false

  endpoint = local.use_dns ? "wg.${local.dns_zone_suffix}" : module.wireguard_vpn.public_ip

  wireguard_port       = 41194
  wireguard_public_key = nonsensitive(jsondecode(data.aws_secretsmanager_secret_version.wireguard.secret_string)["public_key"])
}

# self-hosted wireguard VPN on EC2
module "wireguard_vpn" {
  source = "../../modules/wireguard-ec2"

  vpc_id    = module.vpc.vpc_id
  subnet_id = module.vpc.public_subnets[0]

  port = local.wireguard_port

  //ssh_key_name = "mysshkey" // TODO: you might wanna need to SSH/SSM into your EC2 instance for debugging in case of issues

  ami_id = var.wireguard_ami // packer
}

# resource "aws_route53_record" "wireguard" {
#   zone_id = aws_route53_zone.primary.zone_id
#   name    = "wg.${local.dns_zone_suffix}"
#   type    = "A"

#   ttl     = "300"
#   records = [module.wireguard_vpn.public_ip]
# }

data "aws_secretsmanager_secret" "wireguard" {
  name = "wireguard"
}

data "aws_secretsmanager_secret_version" "wireguard" {
  secret_id = data.aws_secretsmanager_secret.wireguard.id
}

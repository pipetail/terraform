output "vpn_config" {
  description = "wireguard VPN client config"

  value = <<END
# this should come right under your PrivateKey in [Interface] block
# .2 is the first available address as of now, don't forget to bump this up
Address = 10.1.0.2/32

[Peer]
PublicKey = ${local.wireguard_public_key}
AllowedIPs = ${var.vpc_cidr}
Endpoint = ${local.endpoint}:${local.wireguard_port}

END
}

output "packer_inputs" {
  description = "some inputs for packer build"

  value = {
    subnet_id  = module.vpc.public_subnets[0]
    aws_region = var.region
  }
}

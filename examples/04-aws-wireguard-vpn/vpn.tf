locals {
  dns_zone_suffix = "example.org"
  use_dns         = false

  endpoint = local.use_dns ? "wg.${local.dns_zone_suffix}" : module.wireguard_vpn.public_ip

  wireguard_port       = 41194
  wireguard_public_key = var.wireguard_public_key
}

resource "aws_iam_role" "wireguard" {
  name = "${var.name_prefix}-wireguard"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowEC2ToAssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "wireguard_secret" {
  name = "${var.name_prefix}-wireguard-secret"
  role = aws_iam_role.wireguard.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "ReadWireGuardSecret"
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = [data.aws_secretsmanager_secret.wireguard.arn]
    }]
  })
}

resource "aws_iam_instance_profile" "wireguard" {
  name = "${var.name_prefix}-wireguard"
  role = aws_iam_role.wireguard.name
}

# self-hosted wireguard VPN on EC2
module "wireguard_vpn" {
  source = "../../modules/wireguard-ec2"

  vpc_id    = module.vpc.vpc_id
  subnet_id = module.vpc.public_subnets[0]

  port = local.wireguard_port

  //ssh_key_name = "mysshkey" // TODO: you might wanna need to SSH/SSM into your EC2 instance for debugging in case of issues

  ami_id               = var.wireguard_ami // packer
  iam_instance_profile = aws_iam_instance_profile.wireguard.name
  user_data = templatefile("${path.module}/wireguard-user-data.sh.tftpl", {
    runtime_config = jsonencode({
      public_key = var.wireguard_public_key
      region     = var.region
      secret_arn = data.aws_secretsmanager_secret.wireguard.arn
    })
  })
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

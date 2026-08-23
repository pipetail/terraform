module "sg" {
  #checkov:skip=CKV_TF_1:Using registry versioned modules
  source  = "terraform-aws-modules/security-group/aws"
  version = "6.0.0"

  name        = "wireguard-vpn"
  description = "wireguard vpn"
  vpc_id      = var.vpc_id

  ingress_rules = {
    wireguard = {
      from_port   = var.port
      to_port     = var.port
      ip_protocol = "udp"
      cidr_ipv4   = "0.0.0.0/0"
      description = "Allow wireguard from internet"
    }
  }

  // This host NATs VPN client traffic to arbitrary internet destinations, so
  // open egress is the function of the module rather than an oversight.
  egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
      description = "Allow all egress"
    }
  }
}

module "ec2_instance" {
  #checkov:skip=CKV_TF_1:Using registry versioned modules
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 6.0"

  create = var.create_instance

  name = "wireguard-vpn"

  ami           = var.ami_id
  instance_type = "t2.micro"

  key_name   = var.ssh_key_name
  monitoring = true

  iam_instance_profile        = var.iam_instance_profile
  user_data                   = var.user_data
  user_data_replace_on_change = true

  vpc_security_group_ids      = [module.sg.id]
  subnet_id                   = var.subnet_id
  associate_public_ip_address = true

  // The boot service writes the WireGuard private key to this volume after it
  // retrieves the secret, so the running volume must remain encrypted.
  root_block_device = {
    encrypted = true
  }
}

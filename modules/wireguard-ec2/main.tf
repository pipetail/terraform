
module "sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.17.2"

  name        = "wireguard-vpn"
  description = "wireguard vpn"
  vpc_id      = var.vpc_id

  ingress_with_cidr_blocks = [{
    from_port   = var.port
    to_port     = var.port
    protocol    = "udp"
    cidr_blocks = "0.0.0.0/0"
    description = "Allow wireguard from internet"
  }]

  egress_with_cidr_blocks = [{
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = "0.0.0.0/0"
    description = "Allow all egress"
  }]
}

module "ec2_instance" {

  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 4.0"

  create = var.create_instance

  name = "wireguard-vpn"

  ami           = var.ami_id
  instance_type = "t2.micro"

  key_name   = var.ssh_key_name
  monitoring = true

  vpc_security_group_ids      = [module.sg.security_group_id]
  subnet_id                   = var.subnet_id
  associate_public_ip_address = true
}

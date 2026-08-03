module "vpc" {
  #checkov:skip=CKV_TF_1:Using registry versioned modules
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.16.0"

  name = "${var.name_prefix}-main-vpc"
  cidr = var.vpc_cidr

  enable_nat_gateway = false
  single_nat_gateway = false

  azs             = ["${var.region}a", "${var.region}b"] #FIXME: Only 2 hardcoded regions
  public_subnets  = var.subnets.public
  private_subnets = var.subnets.private

  create_database_subnet_group = false
  enable_dns_hostnames         = true

  // map_public_ip_on_launch is deliberately left at the module default of
  // false. The VPN host asks for its own public address via
  // associate_public_ip_address in modules/wireguard-ec2, so turning it on at
  // the subnet level only means anything else launched into these subnets
  // silently gets a public IP too.

  manage_default_network_acl    = false
  manage_default_security_group = false
  manage_default_route_table    = false
}

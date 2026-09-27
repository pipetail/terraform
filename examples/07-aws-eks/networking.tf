module "vpc" {
  #checkov:skip=CKV_TF_1:Using registry versioned modules
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.6.1"

  name = "${var.name_prefix}-vpc"
  cidr = var.vpc_cidr

  enable_nat_gateway = true
  single_nat_gateway = true

  azs                  = ["${var.region}a", "${var.region}b"]
  public_subnets       = var.subnets.public
  private_subnets      = var.subnets.private
  enable_dns_hostnames = true
}

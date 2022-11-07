module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.14.4"

  name = "${var.name_prefix}-main-vpc"
  cidr = var.vpc_cidr

  enable_nat_gateway = false
  single_nat_gateway = false

  azs                          = ["${var.region}a", "${var.region}b"] #FIXME: Only 2 hardcoded regions
  public_subnets               = var.subnets.public
  private_subnets              = var.subnets.private
  create_database_subnet_group = false
  enable_dns_hostnames         = true
}

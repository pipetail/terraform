module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.14.4"

  name = "${var.name_prefix}-main-vpc"
  cidr = var.vpc_cidr

  enable_nat_gateway = false
  single_nat_gateway = false

  azs                          = ["${var.region}a", "${var.region}b"] #FIXME: Only 2 hardcoded regions
  public_subnets               = var.subnets.public
  elasticache_subnets          = var.subnets.elasticache
  private_subnets              = var.subnets.private
  database_subnets             = var.subnets.database
  create_database_subnet_group = true
  enable_dns_hostnames         = true
}

# Specific security group for all VPC endpoints
module "sg_vpc_endpoints" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.16.0"

  name        = "vpc_endpoints"
  description = "Security group VPC endpoints"
  vpc_id      = module.vpc.vpc_id

  ingress_with_cidr_blocks = [{
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = "0.0.0.0/0"
    description = "Allow traffic to endpoint from VPC"

  }]
  egress_with_cidr_blocks = [{
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = "0.0.0.0/0"
    description = "Allow outgoing traffic"
  }]
}

# VPC Endpoints to AWS services
#   ECR - for containers to be able to pull docker images
#   S3 - for ECR and for bucket manipulation
module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "3.18.1"

  security_group_ids = [module.sg_vpc_endpoints.security_group_id]
  vpc_id             = module.vpc.vpc_id
  endpoints = {
    s3 = {
      service         = "s3"
      service_type    = "Gateway"
      route_table_ids = module.vpc.private_route_table_ids
    },
    ecr_api = {
      service             = "ecr.api"
      subnet_ids          = module.vpc.private_subnets
      private_dns_enabled = true
    },
    ecr_dkr = {
      service             = "ecr.dkr"
      subnet_ids          = module.vpc.private_subnets
      private_dns_enabled = true
    },
  }
}

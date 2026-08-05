module "vpc" {
  #checkov:skip=CKV_TF_1:Using registry versioned modules
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.6.1"

  name = "${var.name_prefix}-main-vpc"
  cidr = var.vpc_cidr

  enable_nat_gateway = true
  single_nat_gateway = true

  azs                          = ["${var.region}a", "${var.region}b"]
  public_subnets               = var.subnets.public
  elasticache_subnets          = var.subnets.elasticache
  private_subnets              = var.subnets.private
  database_subnets             = var.subnets.database
  create_database_subnet_group = true
  enable_dns_hostnames         = true

  enable_flow_log                                 = true
  create_flow_log_cloudwatch_log_group            = true
  create_flow_log_cloudwatch_iam_role             = true
  flow_log_max_aggregation_interval               = 60
  flow_log_cloudwatch_log_group_name_prefix       = "/aws/vpc-flow-logs/"
  flow_log_cloudwatch_log_group_retention_in_days = 90
  flow_log_cloudwatch_log_group_kms_key_id        = aws_kms_key.main.arn
}

# Specific security group for all VPC endpoints
module "sg_vpc_endpoints" {
  #checkov:skip=CKV_TF_1:Using registry versioned modules
  source  = "terraform-aws-modules/security-group/aws"
  version = "6.0.0"

  name        = "vpc_endpoints"
  description = "Security group VPC endpoints"
  vpc_id      = module.vpc.vpc_id

  // Interface endpoints terminate on an ENI bound to this group and only ever
  // need 443 from inside the VPC. Only a Gateway endpoint is declared today,
  // which ignores security groups entirely — so this is closed before the first
  // interface endpoint (ECR, SSM, Secrets Manager) makes it reachable.
  ingress_rules = {
    https = {
      from_port   = 443
      to_port     = 443
      ip_protocol = "tcp"
      cidr_ipv4   = module.vpc.vpc_cidr_block
      description = "HTTPS to interface endpoints from within the VPC"
    }
  }

  egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
      description = "Allow outgoing traffic"
    }
  }
}

# VPC Endpoints to AWS services
#   ECR - for containers to be able to pull docker images
#   S3 - for ECR and for bucket manipulation
module "vpc_endpoints" {
  #checkov:skip=CKV_TF_1:Using registry versioned modules
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "6.6.1"

  security_group_ids = [module.sg_vpc_endpoints.id]
  vpc_id             = module.vpc.vpc_id
  endpoints = {
    s3 = {
      service         = "s3"
      service_type    = "Gateway"
      route_table_ids = module.vpc.private_route_table_ids
    },
  }
}

resource "aws_elasticache_replication_group" "redis" {
  #checkov:skip=CKV_AWS_30:No encryption in transit yet TODO: do we need it?
  #checkov:skip=CKV_AWS_31:No encryption in transit yet with auth token TODO: do we need it?
  #checkov:skip=CKV_AWS_29:No encryption at rest yet TODO: add it!
  #checkov:skip=CKV_AWS_191:No KMS yet TODO: should we add it?
  replication_group_id = var.redis.cluster_id
  description          = "redis cluster"

  automatic_failover_enabled  = true
  preferred_cache_cluster_azs = ["${var.region}a", "${var.region}b"] #FIXME: Only 2 hardcoded regions
  node_type                   = "cache.t4g.small"
  num_cache_clusters          = var.redis.node_num

  engine         = "redis"
  engine_version = "6.2"

  port               = 6379
  subnet_group_name  = module.vpc.elasticache_subnet_group_name
  security_group_ids = [module.sg_redis.security_group_id]

  parameter_group_name = aws_elasticache_parameter_group.redis.name
}

resource "aws_elasticache_parameter_group" "redis" {
  name   = "redis6-x"
  family = "redis6.x"

  parameter {
    name  = "activerehashing"
    value = "yes"
  }
}

module "sg_redis" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.16.0"

  name        = "sg_redis"
  description = "ElastiCache Redis"
  vpc_id      = module.vpc.vpc_id

  ingress_with_source_security_group_id = [
    # {
    #   description              = "Redis TCP from ECS Fargate"
    #   rule                     = "redis-tcp"
    #   source_security_group_id = // your app sg id
    # },
  ]

  ingress_with_self = [
    {
      rule = "all-all"
    },
  ]

  egress_with_cidr_blocks = [{
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = "0.0.0.0/0"
    description = "Allow outgoing traffic"
  }]
}

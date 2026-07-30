// ElastiCache has no AWS-managed equivalent of RDS's manage_master_user_password,
// so the token is generated here and does land in Terraform state. Treat the
// state bucket as holding this credential.
resource "random_password" "redis_auth_token" {
  length = 64
  // ElastiCache rejects most punctuation in an AUTH token.
  special          = true
  override_special = "!&#$^<>-"
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = var.redis.cluster_id
  description          = "redis cluster"

  // All three are immutable on an existing replication group: turning them on
  // replaces the cluster and drops the cache. Clients must speak TLS and send
  // the AUTH token before this applies. On engine 7.x, transit_encryption_mode
  // = "preferred" allows a staged rollout instead.
  at_rest_encryption_enabled = true
  kms_key_id                 = aws_kms_key.main.arn
  transit_encryption_enabled = true
  auth_token                 = random_password.redis_auth_token.result

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
  #checkov:skip=CKV_TF_1:Using registry versioned modules
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.3.1"

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

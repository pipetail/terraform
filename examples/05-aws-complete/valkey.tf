// ElastiCache has no AWS-managed equivalent of RDS's manage_master_user_password,
// so the token is generated here and does land in Terraform state. Treat the
// state bucket as holding this credential.
resource "random_password" "valkey_auth_token" {
  length = 64
  // ElastiCache rejects most punctuation in an AUTH token.
  special          = true
  override_special = "!&#$^<>-"
}

locals {
  # endoflife.date has no ElastiCache-specific Valkey product, so this tracks
  # upstream Valkey releases, which can reach ElastiCache later.
  # renovate: datasource=endoflife-date depName=valkey versioning=loose
  valkey_version = "9.1.2"
}

resource "aws_elasticache_replication_group" "valkey" {
  replication_group_id = var.valkey.cluster_id
  description          = "valkey cluster"

  // At-rest encryption is immutable on an existing replication group: turning
  // it on replaces the cluster and drops the cache. Transit encryption can be
  // turned on in place through transit_encryption_mode = "preferred" first.
  // Clients must speak TLS and send the AUTH token before it is required.
  at_rest_encryption_enabled = true
  kms_key_id                 = aws_kms_key.main.arn
  transit_encryption_enabled = true
  auth_token                 = random_password.valkey_auth_token.result

  automatic_failover_enabled  = true
  preferred_cache_cluster_azs = ["${var.region}a", "${var.region}b"] #FIXME: Only 2 hardcoded regions
  node_type                   = "cache.t4g.small"
  num_cache_clusters          = var.valkey.node_num

  engine         = "valkey"
  engine_version = local.valkey_version

  port               = 6379
  subnet_group_name  = module.vpc.elasticache_subnet_group_name
  security_group_ids = [module.sg_valkey.id]

  parameter_group_name = aws_elasticache_parameter_group.valkey.name
}

// A major version bump renames the group, and ElastiCache refuses to delete
// the old group while the replication group still uses it.
resource "aws_elasticache_parameter_group" "valkey" {
  name   = "valkey${split(".", local.valkey_version)[0]}"
  family = "valkey${split(".", local.valkey_version)[0]}"

  parameter {
    name  = "activedefrag"
    value = "yes"
  }

  lifecycle {
    create_before_destroy = true
  }
}

module "sg_valkey" {
  #checkov:skip=CKV_TF_1:Using registry versioned modules
  source  = "terraform-aws-modules/security-group/aws"
  version = "6.0.0"

  name        = "sg_valkey"
  description = "ElastiCache Valkey"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = {
    # app = {
    #   description                  = "Valkey TCP from ECS Fargate"
    #   from_port                    = 6379
    #   to_port                      = 6379
    #   ip_protocol                  = "tcp"
    #   referenced_security_group_id = // your app sg id
    # }

    // "self" is resolved by the module to this group's own id.
    self_all = {
      ip_protocol                  = "-1"
      referenced_security_group_id = "self"
      description                  = "All traffic within the group"
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

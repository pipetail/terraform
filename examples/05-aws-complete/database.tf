resource "random_password" "db_master_password" {
  length  = 32
  special = false
}

module "db" {
  #checkov:skip=CKV_TF_1:Using registry versioned modules
  source  = "terraform-aws-modules/rds-aurora/aws"
  version = "9.16.1"

  name          = "${var.name_prefix}-main"
  database_name = "app"

  engine         = "aurora-postgresql"
  engine_version = "16.6"
  engine_mode    = "provisioned"

  instance_class = "db.r6g.large"
  instances = {
    one = {}
    two = { promotion_tier = 2 }
  }

  manage_master_user_password = false
  master_username             = "root"
  master_password             = random_password.db_master_password.result

  storage_encrypted = true
  kms_key_id        = aws_kms_key.main.arn

  vpc_id                = module.vpc.vpc_id
  db_subnet_group_name  = module.vpc.database_subnet_group_name
  create_security_group = true
  security_group_rules = {
    eks_ingress = {
      source_security_group_id = module.eks.worker_security_group_id
    }
  }

  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  enabled_cloudwatch_logs_exports = ["postgresql"]

  backup_retention_period      = 35
  preferred_backup_window      = "03:00-05:00"
  preferred_maintenance_window = "sun:05:00-sun:06:00"

  deletion_protection         = false // you probably want this to be `true` in production
  allow_major_version_upgrade = false
  auto_minor_version_upgrade  = false
  apply_immediately           = false

  // serverlessv2 is not used but this is workaround for not causing drift
  // see https://github.com/hashicorp/terraform-provider-aws/issues/32381
  serverlessv2_scaling_configuration = {
    min_capacity = 0.5
    max_capacity = 1
  }
}

resource "aws_rds_cluster_parameter_group" "main" {
  name   = "${var.name_prefix}-aurora-postgresql16"
  family = "aurora-postgresql16"

  parameter {
    name  = "track_activities"
    value = "1"
  }
}

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
    two = { promotion_tier = 2 } // higher tier = lower failover priority, used as read replica
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

  autoscaling_enabled      = true
  autoscaling_min_capacity = 1
  autoscaling_max_capacity = 3
  autoscaling_target_cpu   = 55

  deletion_protection         = true
  allow_major_version_upgrade = false
  auto_minor_version_upgrade  = false
  apply_immediately           = false
}

resource "aws_rds_cluster_parameter_group" "main" {
  name   = "${var.name_prefix}-aurora-postgresql16"
  family = "aurora-postgresql16"

  parameter {
    name  = "track_activities"
    value = "1"
  }
}

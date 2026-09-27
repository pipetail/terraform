provider "aws" {
  region = var.region
}

terraform {
  required_version = ">= 1.11.0"

  backend "s3" {
    bucket       = "pipetail-examples-terraform-state"
    key          = "08-aws-audit-logging"
    region       = "eu-west-1"
    use_lockfile = true
    encrypt      = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.52, != 6.57.0"
    }
  }
}

data "aws_partition" "current" {}

data "aws_caller_identity" "current" {}

data "aws_iam_role" "github_actions" {
  name = "github_actions_terraform"
}

locals {
  arn_suffix = "${var.region}:${data.aws_caller_identity.current.account_id}"

  // The cloudtrail module derives these names from name_prefix. If they drift
  // from what the module creates, the key policy stops granting the trail and
  // its log group, and creating either one fails on the key policy.
  trail_arn     = "arn:${data.aws_partition.current.partition}:cloudtrail:${local.arn_suffix}:trail/${var.name_prefix}-global-events"
  log_group_arn = "arn:${data.aws_partition.current.partition}:logs:${local.arn_suffix}:log-group:${var.name_prefix}-cloudtrail-logs"
}

module "kms" {
  source = "../../modules/kms"

  region                            = var.region
  key_administrator_arns            = [data.aws_iam_role.github_actions.arn]
  cloudtrail_trail_arns             = [local.trail_arn]
  cloudwatch_log_group_arn_patterns = [local.log_group_arn]
}

module "cloudtrail" {
  source = "../../modules/cloudtrail"

  name_prefix = var.name_prefix
  kms_key_arn = module.kms.kms_key_arn
}

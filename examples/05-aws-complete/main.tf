data "aws_caller_identity" "current" {}

provider "aws" {
  region = var.region
}

provider "kubernetes" {
  host                   = module.eks.endpoint
  cluster_ca_certificate = module.eks.cluster_certificate_authority_data
  token                  = module.eks.token
}

terraform {
  required_version = ">= 1.0.0"

  backend "s3" {
    bucket         = "pipetail-examples-terraform-state"
    key            = "05-aws-complete"
    region         = "eu-west-1"
    dynamodb_table = "terraform-backend"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.66.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.11.0"
    }
  }
}

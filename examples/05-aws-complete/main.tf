provider "aws" {
  region = var.region
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
      version = "=4.31.0"
    }
  }
}

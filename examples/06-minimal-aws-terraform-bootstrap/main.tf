provider "aws" {
  region = var.region
}

terraform {
  required_version = ">= 1.0.0"

  backend "s3" {
    bucket         = "06-minimal-aws-terraform-bootstrap-tf-state-eu-west-1"
    key            = "infrastructure"
    region         = "eu-west-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "=4.16.0"
    }
  }
}

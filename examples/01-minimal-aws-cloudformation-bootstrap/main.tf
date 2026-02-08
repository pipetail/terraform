provider "aws" {
  region = var.region
}

terraform {
  required_version = ">= 1.6.0"

  backend "s3" {
    bucket       = "pipetail-examples-terraform-state"
    key          = "infrastructure"
    region       = "eu-west-1"
    use_lockfile = true
    encrypt      = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "=4.16.0"
    }
  }
}

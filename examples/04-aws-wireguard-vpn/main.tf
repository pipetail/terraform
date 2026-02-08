provider "aws" {
  region = var.region
}

terraform {
  required_version = ">= 1.6.0"

  backend "s3" {
    bucket       = "pipetail-examples-terraform-state"
    key          = "04-aws-wireguard-vpn"
    region       = "eu-west-1"
    use_lockfile = true
    encrypt      = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.81.0"
    }
  }
}

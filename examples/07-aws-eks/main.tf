provider "aws" {
  region = var.region

  // The e2e workflow looks for anything still carrying this tag after destroy.
  default_tags {
    tags = {
      example = "07-aws-eks"
    }
  }
}

terraform {
  required_version = ">= 1.11.0"

  backend "s3" {
    bucket       = "pipetail-examples-terraform-state"
    key          = "07-aws-eks"
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

terraform {
  required_version = ">= 1.0.0"
}

module "bootstrap" {
  source  = "trussworks/bootstrap/aws"
  version = "3.0.0"

  region        = "eu-west-1"
  account_alias = "06-minimal-aws-terraform-bootstrap"
}

output "bootstrap" {
  value       = module.bootstrap
  description = "bootstrap outputs to fill in your main.tf provider block"
}

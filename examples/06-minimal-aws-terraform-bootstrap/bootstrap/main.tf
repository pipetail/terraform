terraform {
  required_version = ">= 1.0.0"
}

module "bootstrap" {
  //source  = "github.com/pipetail/terraform//modules/aws-bootstrap"
  source = "../../../modules/aws-bootstrap"

  region      = "eu-west-1"
  name_prefix = "06-minimal-aws-terraform-bootstrap"
}

output "bootstrap" {
  value       = module.bootstrap
  description = "bootstrap outputs to fill in your main.tf provider block"
}

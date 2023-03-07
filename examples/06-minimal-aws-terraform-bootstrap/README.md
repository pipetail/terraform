# minimal AWS example with terraform bootstrap
terraform is used to bootstrap terraform backend (s3 + dynamodb)

terraform.tfstate is not gitignored and stays in the repo

`cd` into bootstrap folder, run `terraform apply` and get someting like this:
```
Apply complete! Resources: 18 added, 0 changed, 0 destroyed.

Outputs:

bootstrap = {
  "dynamodb_table" = "terraform-state-lock"
  "logging_bucket" = "06-minimal-aws-terraform-bootstrap-tf-state-log-eu-west-1"
  "state_bucket" = "06-minimal-aws-terraform-bootstrap-tf-state-eu-west-1"
}
```

then fill these in your main.tf

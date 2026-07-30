# minimal AWS example with Cloudformation bootstrap

> **Legacy — prefer [example 06](../06-minimal-aws-terraform-bootstrap), which bootstraps the
> same backend with `modules/aws-bootstrap`.**
>
> The CloudFormation template here creates a working state bucket, but it is a
> plain template rather than the shared module, so it does not carry the
> controls the module applies to the same bucket:
>
> - no `PublicAccessBlockConfiguration`, so the bucket relies entirely on
>   account-level Block Public Access rather than pinning all four settings
> - no bucket policy denying requests where `aws:SecureTransport` is `false`
> - no access logging, so reads of Terraform state leave no record
> - no lifecycle configuration
>
> It is kept for accounts already bootstrapped this way. New setups should use
> example 06 so the state bucket is managed by the same module everywhere and
> improvements to it apply without editing a template.

CloudFormation is used to bootstrap terraform backend (s3 + dynamodb)

## bootstrap
```
export TERRAFORM_BACKEND_BUCKET_NAME=pipetail-examples-terraform-state

cd bootstrap
./bootstrap.sh
```

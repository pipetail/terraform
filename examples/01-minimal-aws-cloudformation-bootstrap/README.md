# minimal AWS example with Cloudformation bootstrap
CloudFormation is used to bootstrap terraform backend (s3 + dynamodb)

## bootstrap
```
export TERRAFORM_BACKEND_BUCKET_NAME=pipetail-examples-terraform-state

cd bootstrap
./bootstrap.sh
```

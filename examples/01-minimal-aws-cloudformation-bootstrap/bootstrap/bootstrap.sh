#!/usr/bin/env bash
set -Eeuo pipefail #if any error exit 1

TERRAFORM_BACKEND_CF_STACK_NAME="${TERRAFORM_BACKEND_CF_STACK_NAME:-terraform-backend}"
TERRAFORM_BACKEND_BUCKET_NAME="${TERRAFORM_BACKEND_BUCKET_NAME:-pipetail-terraform}"
TERRAFORM_BACKEND_TABLE_NAME="${TERRAFORM_BACKEND_TABLE_NAME:-terraform-backend}"
AWS_REGION="${AWS_REGION:-eu-west-1}"

aws cloudformation deploy --stack-name "$TERRAFORM_BACKEND_CF_STACK_NAME" \
  --parameter-overrides \
  BucketName="$TERRAFORM_BACKEND_BUCKET_NAME" \
  TableName="$TERRAFORM_BACKEND_TABLE_NAME" \
  --template-file ./terraform-backend.json \
  --region "$AWS_REGION" \
  --no-fail-on-empty-changeset \
  --output text

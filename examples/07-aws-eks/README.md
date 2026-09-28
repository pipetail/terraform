# 07-aws-eks

The smallest cluster that proves `modules/eks` works end to end: a VPC with one NAT gateway, a KMS key for secrets encryption, and one arm64 Bottlerocket node group.

It is not kept running. `.github/workflows/eks-e2e.yaml` runs every Monday and on manual dispatch:

1. `terraform apply`
2. wait until every node is `Ready`
3. `terraform destroy`, even when an earlier step failed
4. fail if anything tagged `example = 07-aws-eks` is still there (KMS keys pending deletion excepted)

Run it by hand from the Actions tab before merging a change to `modules/eks`. PRs get a plan only.

The worker AMI is read from the Bottlerocket SSM parameter, not pinned. The cycle therefore tests the newest Bottlerocket release for the configured Kubernetes version.

# AWS audit logging with a customer managed KMS key
This example creates a KMS key with the `kms` module and a multi-region CloudTrail trail with the `cloudtrail` module, which writes to an S3 bucket and a CloudWatch Logs log group, both encrypted with that key.
The key policy lets CloudTrail and CloudWatch Logs use the key only for this trail and this log group.
A GitHub Actions workflow applies it every week, so both modules run against a real account.
The KMS key has `prevent_destroy`, so the workflow applies and never destroys.
Only the first trail in an account records management events for free, so adding this trail to an account that already has one bills every management event it records.

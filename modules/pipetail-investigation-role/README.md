# pipetail-investigation-role

Creates a read-only IAM role that one pipetail IAM role assumes to investigate an AWS account.
The role has the AWS managed `ReadOnlyAccess` policy attached, plus an inline Deny for the reads
that return stored data: S3 objects, SSM parameter and Secrets Manager values, KMS decrypt,
Lambda, CodeBuild, AppConfig and Amplify configuration, EC2 passwords, console output and
instance user data, database and table items, queue and stream messages, Step Functions
execution payloads, container images, CodeCommit content, API Gateway API key values, Cognito
user records and Bedrock retrieval content. It also denies role chaining, federation tokens, SSM
sessions and commands, and the EKS Kubernetes API. CloudWatch Logs reads stay allowed.

The trust policy names a single role ARN and requires the session name `gate-host-agent`, so
every call shows up under that name in CloudTrail. AWS adds actions to `ReadOnlyAccess` over
time, and a new action that reads data stays allowed until it is added to the Deny.
`lambda:ListFunctions` and `ecs:DescribeTaskDefinition` return environment variables, and
`ec2:DescribeLaunchTemplateVersions` returns launch template user data. They stay allowed,
because denying them removes the inventory reads.

## Usage

```hcl
module "pipetail_investigation_role" {
  source = "github.com/pipetail/terraform//modules/pipetail-investigation-role?ref=pipetail-investigation-role-v1.0.0"
}
```

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->

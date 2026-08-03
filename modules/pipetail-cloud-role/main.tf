resource "aws_iam_role" "pipetail_cloud" {
  #checkov:skip=CKV_AWS_61:Account-root principal is the documented cross-account pattern; the external ID condition below is what constrains it
  name        = var.role_name
  description = "Read-only role pipetail.cloud assumes to inspect this account"

  # The external ID is what stops a confused deputy: the portal assumes this role from a
  # single shared AWS account, so without the condition any other tenant of that account
  # could name this role ARN and read the account. It must be the value the portal minted
  # for THIS connection — an ID copied from another connected account fails to assume.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.portal_aws_account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.external_id
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "scan_read" {
  #checkov:skip=CKV_AWS_355:Account-wide Describe/List/Get calls have no resource-level scoping to apply
  name = "PipetailScanRead"
  role = aws_iam_role.pipetail_cloud.id

  # Every action the scan services call, and nothing else — the broad AWS-managed
  # SecurityAudit policy is deliberately not attached. All of these are account-wide
  # Describe/List/Get calls with no resource-level scoping available, hence Resource "*".
  # ce:Get* recommendation calls are the only billable ones (Cost Explorer API, priced
  # per request): https://aws.amazon.com/aws-cost-management/aws-cost-explorer/pricing/
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "PipetailScanRead"
        Effect = "Allow"
        Action = [
          "access-analyzer:ListAnalyzers",
          "budgets:DescribeBudgets",
          "ce:GetAnomalyMonitors",
          "ce:GetReservationPurchaseRecommendation",
          "ce:GetSavingsPlansPurchaseRecommendation",
          "cloudtrail:DescribeTrails",
          "cloudtrail:GetTrailStatus",
          "cloudwatch:GetMetricData",
          "config:DescribeConfigurationRecorderStatus",
          "ec2:DescribeAddresses",
          "ec2:DescribeFlowLogs",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeNatGateways",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSnapshots",
          "ec2:DescribeVolumes",
          "ec2:DescribeVpcs",
          "ec2:GetEbsEncryptionByDefault",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeTargetGroups",
          "guardduty:ListDetectors",
          "iam:GenerateCredentialReport",
          "iam:GetAccountPasswordPolicy",
          "iam:GetCredentialReport",
          "kms:DescribeKey",
          "kms:GetKeyRotationStatus",
          "kms:ListKeys",
          "lambda:ListFunctions",
          "lambda:ListTags",
          "organizations:DescribeOrganization",
          "rds:DescribeDBInstances",
          "s3:GetAccountPublicAccessBlock",
          "s3:GetBucketLocation",
          "s3:GetBucketTagging",
          "s3:ListAllMyBuckets",
          "securityhub:DescribeHub",
          "tag:GetResources",
        ]
        Resource = "*"
      }
    ]
  })
}

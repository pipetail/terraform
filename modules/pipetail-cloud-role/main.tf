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
  # ce:Get* calls are the only billable ones (Cost Explorer API, priced
  # per request): https://aws.amazon.com/aws-cost-management/aws-cost-explorer/pricing/
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "PipetailScanRead"
        Effect = "Allow"
        Action = [
          "access-analyzer:ListAnalyzers",
          "acm:DescribeCertificate",
          "acm:ListCertificates",
          "backup:ListBackupPlans",
          "budgets:DescribeBudgets",
          # DescribeBudgets is authorized against budgets:ViewBudget, not the
          # like-named action — granting only DescribeBudgets denies the call.
          "budgets:ViewBudget",
          "ce:GetAnomalies",
          "ce:GetAnomalyMonitors",
          "ce:GetCostForecast",
          "ce:GetReservationCoverage",
          "ce:GetReservationPurchaseRecommendation",
          "ce:GetSavingsPlansCoverage",
          "ce:GetSavingsPlansPurchaseRecommendation",
          "ce:GetSavingsPlansUtilization",
          "cloudtrail:DescribeTrails",
          "cloudtrail:GetEventSelectors",
          "cloudtrail:GetTrailStatus",
          "cloudtrail:LookupEvents",
          "cloudwatch:DescribeAlarms",
          "cloudwatch:GetMetricData",
          # Compute Optimizer answers only for accounts that opted in (free, one-time);
          # an unenrolled account returns status Inactive rather than an error.
          "compute-optimizer:GetAutoScalingGroupRecommendations",
          "compute-optimizer:GetEBSVolumeRecommendations",
          "compute-optimizer:GetEC2InstanceRecommendations",
          "compute-optimizer:GetEnrollmentStatus",
          "compute-optimizer:GetIdleRecommendations",
          "compute-optimizer:GetLambdaFunctionRecommendations",
          "compute-optimizer:GetRDSDatabaseRecommendations",
          "config:DescribeConfigurationRecorderStatus",
          "ec2:DescribeAddresses",
          "ec2:DescribeFlowLogs",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeInstances",
          "ec2:DescribeNatGateways",
          "ec2:DescribeNetworkAcls",
          "ec2:DescribeReservedInstances",
          "ec2:DescribeRouteTables",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSnapshotAttribute",
          "ec2:DescribeSnapshots",
          "ec2:DescribeVolumes",
          "ec2:DescribeVpcs",
          "ec2:GetEbsEncryptionByDefault",
          "eks:DescribeCluster",
          "eks:DescribeClusterVersions",
          "eks:ListClusters",
          "elasticache:DescribeCacheClusters",
          "elasticache:DescribeReplicationGroups",
          "elasticache:DescribeUpdateActions",
          "elasticfilesystem:DescribeFileSystems",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeTargetGroups",
          "guardduty:GetDetector",
          "guardduty:GetFindings",
          "guardduty:ListDetectors",
          "guardduty:ListFindings",
          "iam:GenerateCredentialReport",
          "iam:GetAccountPasswordPolicy",
          "iam:GetCredentialReport",
          "iam:GetPolicyVersion",
          "iam:ListAttachedUserPolicies",
          "iam:ListEntitiesForPolicy",
          "iam:ListPolicies",
          "iam:ListServerCertificates",
          "iam:ListUsers",
          "kms:DescribeKey",
          "kms:GetKeyRotationStatus",
          "kms:ListKeys",
          "lambda:ListFunctions",
          "lambda:ListTags",
          "logs:DescribeLogGroups",
          "organizations:DescribeOrganization",
          "rds:DescribeDBClusters",
          "rds:DescribeDBInstances",
          "rds:DescribeDBMajorEngineVersions",
          "rds:DescribeEvents",
          "rds:DescribePendingMaintenanceActions",
          "rds:DescribeReservedDBInstances",
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets",
          "s3:GetAccountPublicAccessBlock",
          "s3:GetBucketLocation",
          "s3:GetBucketLogging",
          "s3:GetBucketPolicy",
          "s3:GetBucketTagging",
          "s3:ListAllMyBuckets",
          "savingsplans:DescribeSavingsPlans",
          "secretsmanager:ListSecrets",
          "securityhub:DescribeHub",
          "tag:GetResources",
        ]
        Resource = "*"
      },
      {
        # The only write this role holds: a one-time Compute Optimizer enrollment.
        # The service produces no recommendations until an account opts in.
        Sid      = "PipetailComputeOptimizerOptIn"
        Effect   = "Allow"
        Action   = ["compute-optimizer:UpdateEnrollmentStatus"]
        Resource = "*"
      },
      {
        # First-time enrollment creates AWSServiceRoleForComputeOptimizer, so without
        # this the opt-in call fails on exactly the accounts that never opted in.
        # The condition pins the grant to that one service-linked role.
        Sid      = "PipetailComputeOptimizerSlr"
        Effect   = "Allow"
        Action   = ["iam:CreateServiceLinkedRole"]
        Resource = "*"
        Condition = {
          StringEquals = { "iam:AWSServiceName" = "compute-optimizer.amazonaws.com" }
        }
      },
      {
        # Reads the forwarded-event timeline out of the alerting Lambda's log group.
        # Scoped to that one log group rather than "*": FilterLogEvents on every group
        # would expose whatever the account's other functions log, which is a different
        # class of data from the metadata the statement above reads. A consumer that
        # renamed the function must set alerting_log_group to match, or this statement
        # matches nothing and the timeline stays empty.
        Sid      = "PipetailAlertingLogRead"
        Effect   = "Allow"
        Action   = ["logs:FilterLogEvents"]
        Resource = "arn:aws:logs:*:*:log-group:${var.alerting_log_group}:*"
      }
    ]
  })
}

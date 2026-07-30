locals {
  cluster_oidc_issuer = replace(var.cluster_oidc_issuer_url, "https://", "")
}

resource "aws_iam_role" "this" {
  name = "${var.name_prefix}eks-cluster-autoscaler"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.cluster_oidc_issuer}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {

          StringLike = {
            "${local.cluster_oidc_issuer}:sub" = "system:serviceaccount:${var.namespace}:${var.name}-aws-cluster-autoscaler"
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "this" {
  #checkov:skip=CKV_AWS_355: autoscaling Describe* and ec2:DescribeLaunchTemplateVersions do not support resource-level permissions
  name = "${var.name_prefix}eks-cluster-autoscaling"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid = "Discovery"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeTags",
          "ec2:DescribeLaunchTemplateVersions",
        ]
        Resource = [
          "*",
        ]
        Effect = "Allow"
      },
      {
        // Scaling and termination are separated from the read-only actions so
        // they can carry a condition. Left on "*" alongside them, this role
        // could zero the capacity of, or terminate instances in, any ASG in the
        // account — including other clusters and unrelated fleets — and the
        // calls would look like ordinary autoscaling activity in CloudTrail.
        Sid = "ScaleOwnedGroups"
        Action = [
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup",
        ]
        Resource = [
          "*",
        ]
        Effect = "Allow"
        Condition = {
          StringEquals = {
            "autoscaling:ResourceTag/k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this.arn
}

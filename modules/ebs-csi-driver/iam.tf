locals {
  cluster_oidc_issuer = replace(var.cluster_oidc_issuer_url, "https://", "")

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateSnapshot",
          "ec2:AttachVolume",
          "ec2:DetachVolume",
          "ec2:ModifyVolume",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeInstances",
          "ec2:DescribeSnapshots",
          "ec2:DescribeTags",
          "ec2:DescribeVolumes",
          "ec2:DescribeVolumesModifications",
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateTags",
        ]
        Resource = [
          "arn:aws:ec2:*:*:volume/*",
          "arn:aws:ec2:*:*:snapshot/*",
        ]
        Condition = {
          StringEquals = {
            "ec2:CreateAction" = [
              "CreateVolume",
              "CreateSnapshot",
            ]
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DeleteTags",
        ]
        Resource = [
          "arn:aws:ec2:*:*:volume/*",
          "arn:aws:ec2:*:*:snapshot/*",
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateVolume",
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:RequestTag/ebs.csi.aws.com/cluster" = "true"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateVolume",
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:RequestTag/CSIVolumeName" = "*"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DeleteVolume",
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "ec2:ResourceTag/CSIVolumeName" = "*"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DeleteVolume",
        ]
        Resource = "*",
        Condition = {
          StringLike = {
            "ec2:ResourceTag/ebs.csi.aws.com/cluster" = "true"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DeleteSnapshot",
        ]
        Resource = "*",
        Condition = {
          StringLike = {
            "ec2:ResourceTag/CSIVolumeSnapshotName" = "*"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DeleteSnapshot",
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "ec2:ResourceTag/ebs.csi.aws.com/cluster" = "true"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role" "this_controller" {
  name = "${var.name_prefix}-eks-ebs-csi-controller"

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
            "${local.cluster_oidc_issuer}:sub" = "system:serviceaccount:${var.namespace}:ebs-csi-controller-sa"
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "this_controller" {
  name = "${var.name_prefix}-eks-ebs-csi-controller"

  // as per https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html
  // or  https://raw.githubusercontent.com/kubernetes-sigs/aws-ebs-csi-driver/v1.0.0/docs/example-iam-policy.json
  policy = local.policy
}

resource "aws_iam_role_policy_attachment" "this_controller" {
  role       = aws_iam_role.this_controller.name
  policy_arn = aws_iam_policy.this_controller.arn
}

resource "aws_iam_role" "this_node" {
  name = "${var.name_prefix}-eks-ebs-csi-node"

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
            "${local.cluster_oidc_issuer}:sub" = "system:serviceaccount:${var.namespace}:ebs-csi-node-sa"
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "this_node" {
  name   = "${var.name_prefix}-eks-ebs-csi-node"
  policy = local.policy
}

resource "aws_iam_role_policy_attachment" "this_node" {
  role       = aws_iam_role.this_node.name
  policy_arn = aws_iam_policy.this_node.arn
}

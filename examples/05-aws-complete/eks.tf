module "eks" {
  source = "../../modules/eks"

  name                  = "${var.name_prefix}-prod"
  control_plane_subnets = module.vpc.private_subnets

  vpc_id = module.vpc.vpc_id

  k8s_version = "1.27"

  kms_key_administrators         = [data.aws_iam_role.github_actions.arn]
  secrets_encryption_kms_key_arn = aws_kms_key.main.arn

  allow_ingress = {
    "http" = {
      source_security_group_id = module.sg_alb.security_group_id
      port                     = local.nginx_ingress_ports["http"]
      protocol                 = "tcp"
    },

    "https" = {
      source_security_group_id = module.sg_alb.security_group_id
      port                     = local.nginx_ingress_ports["https"]
      protocol                 = "tcp"
    },
  }

  worker_groups = [
    {
      name          = "mainpool"
      instance_type = "m5a.large"
      asg_max_size  = 6
      asg_min_size  = 1
      subnets       = module.vpc.private_subnets

      target_group_arns = [aws_alb_target_group.nginx_ingress.arn]

      set_taint   = false
      max_pods    = 17
      market_type = null
    }
  ]

  map_roles = [
    { // terraform github actions need to have access too!
      // somewhere we'd do: rolearn  = module.github_oidc.role_arn
      rolearn  = data.aws_iam_role.github_actions.arn
      username = "infrastructure:{{SessionName}}"
      groups = [
        "system:masters",
      ]
    },
    {
      rolearn  = aws_iam_role.eks_access_administrator.arn
      username = "administrator:{{SessionName}}"
      groups = [
        "system:masters", // administrators should have full access
      ]
    },
  ]
}

// roles and groups for the EKS access
resource "aws_iam_role" "eks_access_administrator" {
  name = "eks_administrator"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          AWS = [
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root",
          ]
        }
        Effect = "Allow"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_access_administrator_kubeconfig" {
  policy_arn = aws_iam_policy.eks_kubeconfig.arn
  role       = aws_iam_role.eks_access_administrator.name
}

resource "aws_iam_policy" "eks_kubeconfig" {
  name        = "eks_kubeconfig"
  path        = "/"
  description = "allow obtaining of kubeconfig for all EKS clusters"

  policy = jsonencode({
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster"
        ]
        Resource = [
          "*",
        ]
      }
    ]
    Version = "2012-10-17"
  })
}

// policies that allow sts:AssumeRole for the EKS groups
resource "aws_iam_policy" "eks_access_administrator_allow_assume" {
  name = "eks_administrator_allow_assume"
  path = "/"

  policy = jsonencode({
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sts:AssumeRole",
        ]
        Resource = [
          aws_iam_role.eks_access_administrator.arn,
        ],
      }
    ]
    Version = "2012-10-17"
  })
}

// groups for the EKS access, user assigned to such group
// will be able to assume the role
resource "aws_iam_group" "eks_access_administrator" {
  name = "eks-administrators"
}

resource "aws_iam_group_policy_attachment" "eks_access_administrator" {
  group      = aws_iam_group.eks_access_administrator.name
  policy_arn = aws_iam_policy.eks_access_administrator_allow_assume.arn
}

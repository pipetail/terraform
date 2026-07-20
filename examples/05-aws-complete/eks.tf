module "eks" {
  source = "../../modules/eks"

  name                  = "${var.name_prefix}-prod"
  control_plane_subnets = module.vpc.private_subnets

  vpc_id = module.vpc.vpc_id

  k8s_version      = "1.36"
  k8s_architecture = "arm64"

  // bottlerocket v1.62.1, bumped by the update-bottlerocket-ami workflow
  worker_ami_id = "ami-0db30b8c57f5ab16a"

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
      instance_type = "m7g.large"
      asg_max_size  = 6
      asg_min_size  = 1
      subnets       = module.vpc.private_subnets

      target_group_arns = [aws_alb_target_group.nginx_ingress.arn]

      set_taint     = false
      capacity_type = "ON_DEMAND"
    }
  ]

  access_entries = {
    // administrators assume this role to get full cluster access.
    // the github actions role that applies terraform is the cluster creator
    // and gets admin via enable_cluster_creator_admin_permissions in the module.
    administrator = {
      principal_arn = aws_iam_role.eks_access_administrator.arn
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }
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
  #checkov:skip=CKV_AWS_355:Wildcard is intentional to allow describing all EKS clusters
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

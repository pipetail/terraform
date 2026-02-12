locals {
  default_tags = {
    "k8s.io/cluster-autoscaler/enabled"     = "true"
    "k8s.io/cluster-autoscaler/${var.name}" = "owned"
  }
}

module "eks" {
  #checkov:skip=CKV_TF_1:Using registry versioned modules
  source  = "terraform-aws-modules/eks/aws"
  version = "21.15.1"

  cluster_endpoint_public_access = true

  cluster_addons = {
    coredns = {
      addon_version = data.aws_eks_addon_version.coredns.version
      timeouts = {
        create = "25m"
        delete = "10m"
      }
    }
    kube-proxy = {
      addon_version = data.aws_eks_addon_version.kube_proxy.version
    }
    vpc-cni = {
      addon_version = data.aws_eks_addon_version.vpc_cni.version
      #service_account_role_arn = module.vpc_cni_irsa.iam_role_arn
    }
    aws-ebs-csi-driver = {
      addon_version     = data.aws_eks_addon_version.ebs_csi_driver.version
      resolve_conflicts = "OVERWRITE"
    }
  }

  # Self managed node groups will not automatically create the aws-auth configmap so we need to
  create_aws_auth_configmap = true
  manage_aws_auth_configmap = true

  kms_key_enable_default_policy = true
  kms_key_administrators        = var.kms_key_administrators


  cluster_encryption_config = {
    resources        = ["secrets"]
    provider_key_arn = var.secrets_encryption_kms_key_arn
  }

  cluster_name    = var.name
  cluster_version = var.k8s_version
  subnet_ids      = var.control_plane_subnets
  vpc_id          = var.vpc_id

  self_managed_node_group_defaults = {
    iam_role_additional_policies = {
      ssm = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      // AmazonEBSCSIDriverPolicy is definitely not needed by all nodes, only by csi-driver, it's here just for simplicity (EKS module doesn't support it)
      csi = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
    }
  }

  aws_auth_roles = var.map_roles
  aws_auth_users = var.map_users

  self_managed_node_groups = {
    for i, v in var.worker_groups : "nodegroup${i}" => {
      name          = v.name
      instance_type = v.instance_type

      iam_role_attach_cni_policy = true

      platform = "bottlerocket"
      ami_id   = data.aws_ami.bottlerocket_ami.id

      min_size     = v.asg_min_size
      max_size     = v.asg_max_size
      desired_size = v.asg_min_size

      subnets = v.subnets

      bootstrap_extra_args = <<-EOT
        [settings.host-containers.admin]
        enabled = false

        [settings.host-containers.control]
        enabled = true

        # extra args added
        [settings.kernel]
        lockdown = "integrity"

        [settings.kernel.sysctl]
        "net.ipv6.conf.all.disable_ipv6" = "1"
        "net.ipv6.conf.default.disable_ipv6" = "1"

        [settings.kubernetes.node-labels]
        nodepool = "main"
      EOT

      target_group_arns = v.target_group_arns

      // see https://eu-central-1.console.aws.amazon.com/ec2/v2/home?region=eu-central-1#ImageDetails:imageId=ami-00b9b96f830a6c28b
      root_volume_size = 2

      // ephemeral storage
      additional_ebs_volumes = [
        {
          block_device_name     = "/dev/xvdb",
          volume_size           = 20,
          volume_type           = "gp3",
          delete_on_termination = true,
        }
      ]

      market_type = v.market_type

      tags = merge(
        local.default_tags,
        {
          key                 = "k8s.io/cluster-autoscaler/node-template/label/nodepool"
          value               = v.name
          propagate_at_launch = true
        },
      )
    }
  }
}

# TODO:
# module "vpc_cni_irsa" {
#   source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
#   version = "~> 5.0"

#   role_name_prefix      = "VPC-CNI-IRSA"
#   attach_vpc_cni_policy = true
#   #vpc_cni_enable_ipv6   = true

#   oidc_providers = {
#     main = {
#       provider_arn               = module.eks.oidc_provider_arn
#       namespace_service_accounts = ["kube-system:aws-node"]
#     }
#   }
# }

resource "aws_security_group_rule" "ingress" {
  for_each = var.allow_ingress

  type        = "ingress"
  description = "Ingress to EKS Worker nodes"

  source_security_group_id = each.value.source_security_group_id
  protocol                 = each.value.protocol
  from_port                = each.value.port
  to_port                  = each.value.port
  security_group_id        = module.eks.node_security_group_id
}

# this needs to be configured for properly working NodePorts
resource "aws_security_group_rule" "eks_workers_to_eks_workers_all" {
  type        = "ingress"
  description = "EKS between workers all traffic"

  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = module.eks.node_security_group_id
  from_port                = 0
  security_group_id        = module.eks.node_security_group_id
}

locals {
  default_tags = {
    "k8s.io/cluster-autoscaler/enabled"     = "true"
    "k8s.io/cluster-autoscaler/${var.name}" = "owned"
  }

  access_entries = length(var.map_roles) > 0 || length(var.map_users) > 0 ? merge(
    { for role in var.map_roles :
      role.rolearn => {
        kubernetes_groups = role.groups
        principal_arn     = role.rolearn
      }
    },
    { for user in var.map_users :
      user.userarn => {
        kubernetes_groups = user.groups
        principal_arn     = user.userarn
      }
    }
  ) : {}
}

module "eks" {
  #checkov:skip=CKV_TF_1:Using registry versioned modules
  source  = "terraform-aws-modules/eks/aws"
  version = "21.15.1"

  name               = var.name
  kubernetes_version = var.k8s_version
  vpc_id             = var.vpc_id
  subnet_ids         = var.control_plane_subnets

  endpoint_public_access = true

  authentication_mode = "API_AND_CONFIG_MAP"

  kms_key_enable_default_policy = true
  kms_key_administrators        = var.kms_key_administrators

  encryption_config = {
    resources        = ["secrets"]
    provider_key_arn = var.secrets_encryption_kms_key_arn
  }

  addons = {
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
    }
    aws-ebs-csi-driver = {
      addon_version     = data.aws_eks_addon_version.ebs_csi_driver.version
      resolve_conflicts = "OVERWRITE"
    }
  }

  access_entries = local.access_entries

  self_managed_node_groups = {
    for i, v in var.worker_groups : "nodegroup${i}" => {
      name          = v.name
      instance_type = v.instance_type

      ami_type = "BOTTLEROCKET_x86_64"

      min_size     = v.asg_min_size
      max_size     = v.asg_max_size
      desired_size = v.asg_min_size

      subnets = v.subnets

      iam_role_additional_policies = {
        ssm = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
        csi = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      }

      iam_role_attach_cni_policy = true

      bootstrap_extra_args = <<-EOT
        [settings.host-containers.admin]
        enabled = false

        [settings.host-containers.control]
        enabled = true

        [settings.kernel]
        lockdown = "integrity"

        [settings.kernel.sysctl]
        "net.ipv6.conf.all.disable_ipv6" = "1"
        "net.ipv6.conf.default.disable_ipv6" = "1"

        [settings.kubernetes.node-labels]
        nodepool = "main"
      EOT

      target_group_arns = v.target_group_arns

      root_volume_size = 20

      additional_ebs_volumes = [
        {
          block_device_name     = "/dev/xvdb"
          volume_size           = 20
          volume_type           = "gp3"
          delete_on_termination = true
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

resource "aws_security_group_rule" "eks_workers_to_eks_workers_all" {
  type        = "ingress"
  description = "EKS between workers all traffic"

  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = module.eks.node_security_group_id
  from_port                = 0
  security_group_id        = module.eks.node_security_group_id
}

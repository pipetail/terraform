locals {
  default_tags = {
    "k8s.io/cluster-autoscaler/enabled"     = "true"
    "k8s.io/cluster-autoscaler/${var.name}" = "owned"
  }

  is_arm64              = contains(["arm64", "aarch64"], var.k8s_architecture)
  bottlerocket_ami_type = local.is_arm64 ? "BOTTLEROCKET_ARM_64" : "BOTTLEROCKET_x86_64"
}

module "eks" {
  #checkov:skip=CKV_TF_1:Using registry versioned modules
  source  = "terraform-aws-modules/eks/aws"
  version = "21.25.0"

  // Leaving endpoint_public_access_cidrs unset falls through to the upstream
  // default of 0.0.0.0/0, i.e. the Kubernetes API is reachable from anywhere
  // and any leaked credential mapped to an access entry is usable with no
  // network control in front of it. Narrowing it needs the applier to have a
  // stable egress address first — GitHub-hosted runners do not.
  endpoint_private_access      = true
  endpoint_public_access       = true
  endpoint_public_access_cidrs = var.endpoint_public_access_cidrs

  authentication_mode                      = "API"
  enable_cluster_creator_admin_permissions = true
  access_entries                           = var.access_entries

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
      #service_account_role_arn = module.vpc_cni_irsa.iam_role_arn
    }
    // aws-ebs-csi-driver is deliberately not here — see aws_eks_addon.ebs_csi
    // below. It needs a service account role, and a role built from this
    // module's own OIDC provider cannot be fed back into its addons input
    // without forming a dependency cycle.
  }

  kms_key_enable_default_policy = true
  kms_key_administrators        = var.kms_key_administrators


  encryption_config = {
    resources        = ["secrets"]
    provider_key_arn = var.secrets_encryption_kms_key_arn
  }

  name               = var.name
  kubernetes_version = var.k8s_version
  subnet_ids         = var.control_plane_subnets
  vpc_id             = var.vpc_id

  eks_managed_node_groups = {
    for i, v in var.worker_groups : "nodegroup${i}" => {
      name           = v.name
      instance_types = [v.instance_type]

      iam_role_attach_cni_policy = true
      iam_role_additional_policies = {
        ssm = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }

      ami_type                   = local.bottlerocket_ami_type
      ami_id                     = var.worker_ami_id
      enable_bootstrap_user_data = true

      min_size     = v.asg_min_size
      max_size     = v.asg_max_size
      desired_size = v.asg_min_size

      subnet_ids = v.subnets

      capacity_type = v.capacity_type

      labels = {
        nodepool = v.name
      }

      taints = v.set_taint ? {
        nodepool = {
          key    = "nodepool"
          value  = v.name
          effect = "NO_SCHEDULE"
        }
      } : {}

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
      EOT

      // see https://eu-central-1.console.aws.amazon.com/ec2/v2/home?region=eu-central-1#ImageDetails:imageId=ami-00b9b96f830a6c28b
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 2
            volume_type           = "gp3"
            delete_on_termination = true
            encrypted             = true
          }
        }
        // ephemeral storage
        xvdb = {
          device_name = "/dev/xvdb"
          ebs = {
            volume_size           = 20
            volume_type           = "gp3"
            delete_on_termination = true
            encrypted             = true
          }
        }
      }

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

locals {
  # flatten (node group, target group ARN) pairs so each managed node group ASG
  # can be attached to its load balancer target groups (target_group_arns was
  # removed from node groups in EKS module v21)
  node_target_group_attachments = merge([
    for i, v in var.worker_groups : {
      for idx, arn in v.target_group_arns :
      "nodegroup${i}-${idx}" => {
        node_group = "nodegroup${i}"
        arn        = arn
      }
    }
  ]...)
}

resource "aws_autoscaling_attachment" "node_target_groups" {
  for_each = local.node_target_group_attachments

  autoscaling_group_name = one(module.eks.eks_managed_node_groups[each.value.node_group].node_group_autoscaling_group_names)
  lb_target_group_arn    = each.value.arn
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

// AmazonEBSCSIDriverPolicy grants ec2:CreateSnapshot, ec2:AttachVolume and
// ec2:DetachVolume with no condition on volume/* and instance/*, so on a node
// role it lets anything that reaches node credentials snapshot or detach any
// EBS volume in the account — not just this cluster's. Scoped here to the
// controller's service account instead.
module "ebs_csi_irsa" {
  #checkov:skip=CKV_TF_1:Using registry versioned modules
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "6.8.1"

  name                  = substr("${var.name}-ebs-csi-", 0, 32)
  use_name_prefix       = true
  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name = module.eks.cluster_name
  addon_name   = "aws-ebs-csi-driver"

  addon_version            = data.aws_eks_addon_version.ebs_csi_driver.version
  service_account_role_arn = module.ebs_csi_irsa.arn

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

// The addon moves out of the upstream module's addons map rather than being
// replaced. Without this a consumer with a live cluster would see the driver
// destroyed and recreated, which stops volume attach/detach while it is gone.
moved {
  from = module.eks.aws_eks_addon.this["aws-ebs-csi-driver"]
  to   = aws_eks_addon.ebs_csi
}

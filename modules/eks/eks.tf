locals {
  default_tags = [
    {
      key                 = "k8s.io/cluster-autoscaler/enabled"
      value               = "true"
      propagate_at_launch = false
    },
    {
      key                 = "k8s.io/cluster-autoscaler/${var.name}"
      value               = "owned"
      propagate_at_launch = false
    },
  ]
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "17.24.0"

  cluster_encryption_config = [
    {
      provider_key_arn = var.secrets_encryption_kms_key_arn
      resources = [
        "secrets",
      ]
    }
  ]

  cluster_name    = var.name
  cluster_version = var.k8s_version
  subnets         = var.control_plane_subnets
  vpc_id          = var.vpc_id

  map_roles = var.map_roles

  map_users = var.map_users

  worker_groups_launch_template = [
    for i, v in var.worker_groups : {
      name                 = v.name
      instance_type        = v.instance_type
      ami_id               = data.aws_ami.bottlerocket_ami.id
      asg_min_size         = v.asg_min_size
      asg_max_size         = v.asg_max_size
      asg_desired_capacity = v.asg_min_size
      subnets              = v.subnets

      // userdata for the bottlerocket
      userdata_template_file = "${path.module}/assets/userdata.toml"
      userdata_template_extra_args = {
        enable_admin_container   = true
        enable_control_container = true
        aws_region               = data.aws_region.current.name
        max_pods                 = v.max_pods
      }

      additional_userdata = templatefile("${path.module}/assets/userdata_additional.toml", {
        name      = v.name
        set_taint = v.set_taint
      })

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

      tags = concat(
        local.default_tags,
        [
          {
            key                 = "k8s.io/cluster-autoscaler/node-template/label/nodepool"
            value               = v.name
            propagate_at_launch = true
          },
        ]
      )
    }
  ]
}

resource "aws_security_group_rule" "ingress" {
  for_each = var.allow_ingress

  type        = "ingress"
  description = "Ingress to EKS Worker nodes"

  source_security_group_id = each.value.source_security_group_id
  protocol                 = each.value.protocol
  from_port                = each.value.port
  to_port                  = each.value.port
  security_group_id        = module.eks.worker_security_group_id
}

locals {
  default_tags = {
    "k8s.io/cluster-autoscaler/enabled"     = "true"
    "k8s.io/cluster-autoscaler/${var.name}" = "owned"
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.15.1"

  cluster_endpoint_public_access = true

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  # Self managed node groups will not automatically create the aws-auth configmap so we need to
  create_aws_auth_configmap = true
  manage_aws_auth_configmap = true

  cluster_encryption_config = {
    resources        = ["secrets"]
    provider_key_arn = var.secrets_encryption_kms_key_arn
  }

  cluster_name    = var.name
  cluster_version = var.k8s_version
  subnet_ids      = var.control_plane_subnets
  vpc_id          = var.vpc_id

  iam_role_additional_policies = {
    additional = data.aws_iam_policy.ssm.arn
  }

  aws_auth_roles = var.map_roles

  aws_auth_users = var.map_users

  self_managed_node_groups = {
    for i, v in var.worker_groups : i => {
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

      post_bootstrap_user_data = <<-EOT
        cd /tmp
        sudo yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
        sudo systemctl enable amazon-ssm-agent
        sudo systemctl start amazon-ssm-agent
      EOT

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

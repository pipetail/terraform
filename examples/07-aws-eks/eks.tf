// Latest, not pinned: the weekly cycle proves the next Bottlerocket release
// before update-bottlerocket-ami.yaml bumps the pinned AMI in example 05.
data "aws_ssm_parameter" "bottlerocket_ami" {
  name = "/aws/service/bottlerocket/aws-k8s-${var.k8s_version}/arm64/latest/image_id"
}

module "eks" {
  source = "../../modules/eks"

  name                  = var.name_prefix
  control_plane_subnets = module.vpc.private_subnets
  vpc_id                = module.vpc.vpc_id

  k8s_version      = var.k8s_version
  k8s_architecture = "arm64"
  worker_ami_id    = nonsensitive(data.aws_ssm_parameter.bottlerocket_ami.value)

  kms_key_administrators         = [data.aws_iam_role.github_actions.arn]
  secrets_encryption_kms_key_arn = aws_kms_key.eks.arn

  node_group_timeouts = {
    create = "15m"
  }

  worker_groups = [
    {
      name              = "e2e"
      instance_type     = "t4g.medium"
      asg_max_size      = 2
      asg_min_size      = 1
      subnets           = module.vpc.private_subnets
      target_group_arns = []
      set_taint         = false
      capacity_type     = "ON_DEMAND"
    }
  ]
}

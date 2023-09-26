data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "helm_release" "this" {
  name             = var.name
  namespace        = var.namespace
  create_namespace = true
  repository       = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart            = "aws-ebs-csi-driver"
  version          = var.chart_version
  wait             = var.wait
  atomic           = var.atomic

  values = [
    templatefile("${path.module}/values.yaml", {
      node_role_arn       = aws_iam_role.this_node.arn
      controller_role_arn = aws_iam_role.this_controller.arn,
      image_aws_account   = var.image_aws_account
      region              = data.aws_region.current.name
    })
  ]
}

terraform {
  required_version = ">= 1.0.0"
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.5.1"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.13.0"
    }
  }
}

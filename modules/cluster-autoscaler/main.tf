data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "helm_release" "this" {
  name             = var.name
  namespace        = var.namespace
  repository       = "https://kubernetes.github.io/autoscaler"
  chart            = "cluster-autoscaler"
  version          = var.chart_version
  atomic           = var.atomic
  wait             = var.wait
  create_namespace = true

  values = [
    templatefile("${path.module}/values.yaml", {
      cluster_name = var.cluster_name,
      region       = data.aws_region.current.name,
      role_arn     = aws_iam_role.this.arn,
    })
  ]
}

terraform {
  required_version = ">= 1.0.0"
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.5.1"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.13.0"
    }
  }
}

data "aws_eks_addon_version" "coredns" {
  addon_name         = "coredns"
  kubernetes_version = var.k8s_addon_version
}

data "aws_eks_addon_version" "kube_proxy" {
  addon_name         = "kube-proxy"
  kubernetes_version = var.k8s_addon_version
}

data "aws_eks_addon_version" "vpc_cni" {
  addon_name         = "vpc-cni"
  kubernetes_version = var.k8s_addon_version
}

data "aws_eks_addon_version" "ebs_csi_driver" {
  addon_name         = "aws-ebs-csi-driver"
  kubernetes_version = var.k8s_addon_version
}

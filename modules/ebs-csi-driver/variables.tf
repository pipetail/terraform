variable "cluster_oidc_issuer_url" {
  type        = string
  description = "EKS cluster oidc issuer url"
}

variable "name" {
  type        = string
  default     = "aws-ebs-csi-driver"
  description = "Helm release name"
}

variable "namespace" {
  type        = string
  default     = "cluster-autoscaler"
  description = "kubernetes namespace to deploy to"
}

variable "chart_version" {
  type        = string
  default     = "2.11.1"
  description = "get the version via `helm search repo aws-ebs-csi-driver`"
}

variable "atomic" {
  type        = bool
  default     = true
  description = "If set, installation process purges chart on fail. The wait flag will be set automatically if atomic is used."
}

variable "wait" {
  type        = bool
  default     = true
  description = "Will wait until all resources are in a ready state before marking the release as successful. It will wait for as long as timeout."
}

variable "image_aws_account" {
  type        = string
  default     = "602401143452"
  description = "account with add-ons images as per https://docs.aws.amazon.com/eks/latest/userguide/add-ons-images.html"
}

variable "name_prefix" {
  type        = string
  description = "name prefix for unique resource names"
  default     = ""
}

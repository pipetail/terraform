variable "name" {
  type        = string
  default     = "cluster-autoscaler"
  description = "Helm release name"
}

variable "namespace" {
  type        = string
  default     = "cluster-autoscaler"
  description = "kubernetes namespace to deploy to"
}

variable "chart_version" {
  type        = string
  default     = "9.10.7"
  description = "get the version here https://artifacthub.io/packages/helm/cluster-autoscaler/cluster-autoscaler"
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

variable "cluster_name" {
  type        = string
  description = "EKS cluster name"
}

variable "cluster_oidc_issuer_url" {
  type        = string
  description = "EKS cluster oidc issuer url"
}

variable "name_prefix" {
  type        = string
  description = "name prefix for unique resource names"
  default     = ""
}

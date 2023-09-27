variable "name" {
  type        = string
  description = "EKS cluster name"
}

variable "vpc_id" {
  type        = string
  description = "ID of VPC where EKS cluster should belong to"
}

variable "control_plane_subnets" {
  type        = list(string)
  description = "AWS VPC subnets for the EKS control plane"
}

variable "k8s_version" {
  type        = string
  default     = "1.27"
  description = "EKS / Kubernetes version"
}

variable "k8s_addon_version" {
  type        = string
  default     = "1.27"
  description = "EKS addons version"
}

variable "k8s_architecture" {
  type        = string
  default     = "x86_64"
  description = "cpu architecture to use with k8s nodes"
}

variable "kms_key_administrators" {
  type        = list(string)
  default     = []
  description = "KMS key administrators"
}

variable "worker_groups" {
  type = list(object({
    name              = string
    instance_type     = string
    asg_max_size      = number
    asg_min_size      = number
    target_group_arns = list(string)
    subnets           = list(string)
    set_taint         = bool // automatically add a taint with the nodepool name
    max_pods          = number
    market_type       = string
  }))
  description = "k8s worker groups configuration"
}

variable "map_roles" {
  type        = list(any)
  default     = []
  description = "additional roles that should be mapped to aws-auth config map"
}

variable "map_users" {
  type        = list(any)
  default     = []
  description = "additional users that should be mapped to aws-auth config map"
}

variable "allow_ingress" {
  type = map(object({
    source_security_group_id = string
    port                     = number
    protocol                 = string
  }))
  default     = {}
  description = "ingress to k8s nodes to be allowed"
}

variable "secrets_encryption_kms_key_arn" {
  type        = string
  description = "KMS Key ARN for k8s secrets encryption"
}

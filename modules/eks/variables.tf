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

// pinned explicitly rather than resolved via a most_recent data source so that
// node rollouts happen through a reviewed PR (see .github/workflows/update-bottlerocket-ami.yaml)
// instead of silently on the next apply after a new Bottlerocket release.
variable "worker_ami_id" {
  type        = string
  description = "Bottlerocket AMI ID to use for the k8s worker nodes, must match k8s_version and k8s_architecture"

  validation {
    condition     = can(regex("^ami-[0-9a-f]+$", var.worker_ami_id))
    error_message = "worker_ami_id must be a valid AMI ID, e.g. ami-08d4abbd395927beb."
  }
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
    capacity_type     = string
  }))
  description = "k8s worker groups configuration"
}

variable "access_entries" {
  type        = any
  default     = {}
  description = "Map of EKS access entries to create (principal_arn + policy_associations)"
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

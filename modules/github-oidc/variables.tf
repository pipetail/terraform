variable "repository_name" {
  type        = string
  description = "Github org and repository name (full path) to be allowed in OIDC"
  default     = ""
}

variable "managed_policy_arns" {
  type        = list(any)
  description = "IAM Managed Policy ARNs to be attached to the created IAM Role"
  default     = []
}

variable "role_name" {
  type        = string
  description = "IAM Role name to be created"
  default     = "github_actions"
}

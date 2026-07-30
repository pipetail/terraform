variable "repository_name" {
  type        = string
  description = "Github org and repository name (full path) to be allowed in OIDC"
  default     = ""
}

variable "allowed_subjects" {
  type        = list(string)
  description = "Exact OIDC `sub` claims allowed to assume the role, e.g. `repo:org/repo:ref:refs/heads/master`, `repo:org/repo:pull_request`, `repo:org/repo:environment:prod`. Matched with StringEquals, so wildcards are not honoured. Defaults to the repository's master branch only."
  default     = null
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

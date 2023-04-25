variable "roles" {
  description = "Map of IAM Roles that will be assumed from GitHub Actions repos"
  type        = any
  default     = {}
}

variable "create_oidc_provider" {
  default     = true
  type        = bool
  description = "Should we create and manage the OIDC provider for GitHub actions?"
}

variable "oidc_provider_arn" {
  default     = null
  type        = string
  description = "OIDC provider ARN in case create_oidc_provider is false"
}

variable "name_prefix" {
  description = "Used as a name prefix for resources"
  type        = string
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB Table for locking Terraform state."
  default     = "terraform-state-lock"
  type        = string
}

variable "dynamodb_table_tags" {
  description = "Tags of the DynamoDB Table for locking Terraform state."
  default = {
    Name       = "terraform-state-lock"
    Automation = "Terraform"
  }
  type = map(string)
}

variable "region" {
  description = "AWS region."
  type        = string
}

variable "bucket_purpose" {
  description = "Name to identify the bucket's purpose"
  default     = "tf-state"
  type        = string
}


variable "state_bucket_tags" {
  type        = map(string)
  default     = { Automation : "Terraform" }
  description = "Tags to associate with the bucket storing the Terraform state files"
}

variable "state_bucket_force_destroy" {
  type        = bool
  default     = false
  description = "Allow destroying the state bucket while it still holds objects. A destroy then removes every object version along with the bucket, so versioning does not keep the Terraform state recoverable. Leave disabled unless the bucket is genuinely disposable."
}

variable "dynamodb_point_in_time_recovery" {
  type        = bool
  default     = false
  description = "Point-in-time recovery options"
}

variable "create_dynamodb_table" {
  type        = bool
  default     = false
  description = "Create DynamoDB table for Terraform state locking. Not needed when using S3 native locking (use_lockfile = true in backend config, requires Terraform 1.6+)."
}

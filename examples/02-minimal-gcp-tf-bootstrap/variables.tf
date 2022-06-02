# The default region for resources in the project, individual resources should
# have more specific variables defined to specify their region/location which
# increases the flexibility of deployments
variable "region" {
  type        = string
  default     = "europe-west1"
  description = "GCP region to be used for provisioning resources."
}

variable "project" {
  type        = string
  description = "GCP project id"
}

variable "log_retention_period" {
  type        = number
  default     = 14
  description = "Number of days to retain logs for all services in the project."
}

variable "storage_location" {
  type        = string
  default     = "EU"
  description = "Location for object storage."
}

# The location for the app engine; this implicitly defines the region for
# scheduler jobs as specified by the cloudscheduler_location variable but the
# values are sometimes different (as in the default values) so they are kept as
# separate variables.
# https://cloud.google.com/appengine/docs/locations
variable "appengine_location" {
  type        = string
  default     = "europe-west"
  description = "The location for the app engine"
}

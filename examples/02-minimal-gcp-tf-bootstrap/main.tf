terraform {
  backend "gcs" {
    bucket = "pipetail-terraform-state"
    prefix = "infra"
  }
}

data "google_project" "project" {
  project_id = var.project

  depends_on = [
    google_project_service.resourcemanager,
  ]
}

# Cloud Resource Manager needs to be enabled first, before other services.
resource "google_project_service" "resourcemanager" {
  project            = var.project
  service            = "cloudresourcemanager.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "services" {
  project = data.google_project.project.project_id

  for_each = toset([
    "iam.googleapis.com",
    "logging.googleapis.com",
    "stackdriver.googleapis.com",
    "storage.googleapis.com",
  ])
  service            = each.value
  disable_on_destroy = false

  depends_on = [
    google_project_service.resourcemanager,
  ]
}

# Cloud Scheduler requires AppEngine projects!
#
# If your project already has GAE enabled, run `terraform import google_app_engine_application.app $PROJECT_ID`
resource "google_app_engine_application" "app" {
  project     = data.google_project.project.project_id
  location_id = var.appengine_location
}

provider "google" {
  project = var.project
  region  = var.region

  user_project_override = true
}

provider "google-beta" {
  project = var.project
  region  = var.region

  user_project_override = true
}

resource "google_logging_project_bucket_config" "basic" {
  project        = var.project
  location       = "global"
  retention_days = var.log_retention_period
  bucket_id      = "_Default"

  depends_on = [
    google_project_service.services["logging.googleapis.com"],
    google_project_service.services["stackdriver.googleapis.com"],
  ]
}

resource "google_storage_bucket" "audit" {
  #checkov:skip=CKV_GCP_62:This storage bucket is intended for audit logging only
  project  = var.project
  name     = "${var.project}-audit-logs"
  location = var.storage_location

  force_destroy               = true
  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }

    condition {
      num_newer_versions = "120" // TODO: for how long should the audit logs be kept?
    }
  }

  depends_on = [
    google_project_service.services["storage.googleapis.com"],
  ]
}

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.15.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 4.2.1"
    }
  }
}

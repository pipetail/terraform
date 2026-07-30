provider "google" {
  project = "pipetail-terraform"

  region                = "europe-west1"
  user_project_override = true
}

resource "google_storage_bucket" "terraform_state" {
  #checkov:skip=CKV_GCP_62:For simplicity we dont want audit logging for this bucket
  project = "pipetail-terraform"

  name     = "pipetail-terraform-state"
  location = "europe-west1"

  // force_destroy would delete the bucket along with every object version it
  // holds, so the versioning below would stop being a recovery path for state.
  force_destroy = false

  public_access_prevention    = "enforced"
  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }
}

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.56.0"
    }
  }
}

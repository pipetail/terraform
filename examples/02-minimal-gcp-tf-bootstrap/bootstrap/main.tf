provider "google" {
  project = "pipetail-terraform"

  region                = "europe-west1"
  user_project_override = true
}

resource "google_storage_bucket" "terraform_state" {
  #checkov:skip=CKV_GCP_62:For simplicity we dont want audit logging for this bucket
  #checkov:skip=CKV_GCP_29:For simplicity we want to avoid using uniform bucket-level access here (this may be a bad idea though)
  project = "pipetail-terraform"

  name          = "pipetail-terraform-state"
  location      = "europe-west1"
  force_destroy = true

  public_access_prevention = "enforced"

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

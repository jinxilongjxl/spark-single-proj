terraform {
  required_version = ">= 1.3"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# 配置GCP Provider
provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}
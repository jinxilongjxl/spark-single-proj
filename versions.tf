# 配置GCP Provider
provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP Zone"
  type        = string
  default     = "us-central1-a"
}

variable "instance_name" {
  description = "Name of the single Spark node"
  type        = string
  default     = "spark-single"
}

variable "machine_type" {
  description = "GCE Machine type"
  type        = string
  default     = "e2-standard-2"
}

variable "boot_disk_size_gb" {
  description = "Boot disk size in GB"
  type        = number
  default     = 50
}

variable "spark_version" {
  description = "Apache Spark version to install"
  type        = string
  default     = "3.5.1"
}

variable "spark_user" {
  description = "OS user that will run Spark"
  type        = string
  default     = "spark"
}
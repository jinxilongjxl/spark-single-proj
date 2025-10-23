provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# 自定义 VPC
resource "google_compute_network" "spark_vpc" {
  name                    = "spark-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "spark_subnet" {
  name          = "spark-subnet"
  region        = var.region
  network       = google_compute_network.spark_vpc.id
  ip_cidr_range = "10.0.0.0/24"
}

# 防火墙规则：允许 SSH（22）与 Spark WebUI（8080, 4040）
resource "google_compute_firewall" "spark_fw" {
  name    = "spark-allow-internal"
  network = google_compute_network.spark_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22", "8080", "4040", "7077", "8081"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["spark-single"]
}

# 外部 IP
resource "google_compute_address" "spark_ext_ip" {
  name   = "spark-single-ip"
  region = var.region
}

# 计算实例
resource "google_compute_instance" "spark_single" {
  name         = var.instance_name
  machine_type = var.machine_type
  zone         = var.zone
  tags         = ["spark-single"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = var.boot_disk_size_gb
      type  = "pd-standard"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.spark_subnet.id
    access_config {
      nat_ip = google_compute_address.spark_ext_ip.address
    }
  }

  metadata_startup_script = file("${path.module}/scripts/install-spark.sh")

  service_account {
    scopes = ["cloud-platform"]
  }
}
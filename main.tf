# 1. 自定义VPC网络
resource "google_compute_network" "spark_vpc" {
  name                    = var.vpc_name
  auto_create_subnetworks = false
  description             = "Custom VPC for Spark cluster"
}

# 2. 子网配置
resource "google_compute_subnetwork" "spark_subnet" {
  name          = var.subnet_name
  network       = google_compute_network.spark_vpc.name
  ip_cidr_range = var.subnet_cidr
  region        = var.region
}

# 3. 防火墙规则（修复source_ranges重复问题）
resource "google_compute_firewall" "spark_firewall" {
  name    = "spark-firewall"
  network = google_compute_network.spark_vpc.name

  # 允许的端口：内部全端口通信 + 外部SSH(22)和Spark UI(8080)
  allow {
    protocol = "tcp"
    ports    = ["0-65535", "22", "8080"]  # 合并所有需要开放的端口
  }

  # 源IP范围：子网内部IP + 外部访问IP（合并为一个列表）
  source_ranges = [
    var.subnet_cidr,  # 子网内部通信
    "0.0.0.0/0"       # 外部访问（生产环境建议限制IP）
  ]
}

# 4. Spark虚拟机实例（引用外部启动脚本）
resource "google_compute_instance" "spark_node" {
  name         = var.vm_name
  machine_type = "e2-standard-2"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 50
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.spark_subnet.name
    access_config {
      # 分配公网IP
    }
  }

  # 引用scripts目录下的安装脚本（相对路径）
  metadata_startup_script = file("${path.module}/scripts/install-spark.sh")

  depends_on = [
    google_compute_subnetwork.spark_subnet,
    google_compute_firewall.spark_firewall
  ]
}
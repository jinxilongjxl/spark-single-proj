# 1. 创建自定义VPC网络（禁用自动创建子网）
resource "google_compute_network" "spark_vpc" {
  name                    = var.vpc_name
  auto_create_subnetworks = false  # 手动管理子网
  description             = "Custom VPC for Spark cluster"
}

# 2. 在VPC下创建子网
resource "google_compute_subnetwork" "spark_subnet" {
  name          = var.subnet_name
  network       = google_compute_network.spark_vpc.name  # 关联自定义VPC
  ip_cidr_range = var.subnet_cidr  # 子网IP范围
  region        = var.region
}

# 3. 防火墙规则：允许内部通信+必要外部访问
resource "google_compute_firewall" "spark_firewall" {
  name    = "spark-firewall"
  network = google_compute_network.spark_vpc.name  # 关联自定义VPC

  # 规则1：允许VPC内部所有节点通信（Spark节点间通信需要）
  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }
  source_ranges = [var.subnet_cidr]  # 仅允许子网内IP通信

  # 规则2：允许外部访问SSH（22）和Spark Web UI（8080）
  allow {
    protocol = "tcp"
    ports    = ["22", "8080"]
  }
  source_ranges = ["0.0.0.0/0"]  # 生产环境建议限制为特定IP
}

# 4. Spark虚拟机实例（单节点，含Master+Worker）
resource "google_compute_instance" "spark_node" {
  name         = var.vm_name
  machine_type = "e2-standard-2"  # 2vCPU+8GB内存（适合小规模Spark）
  zone         = var.zone

  # 系统盘（Ubuntu 22.04）
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 50  # 50GB磁盘
    }
  }

  # 网络接口：关联自定义子网，分配公网IP（可选）
  network_interface {
    subnetwork = google_compute_subnetwork.spark_subnet.name  # 使用自定义子网
    access_config {
      # 分配公网IP（用于外部访问，若仅内部使用可删除此段）
    }
  }

  # 启动脚本：安装Java、Spark并配置
  metadata_startup_script = file("${path.module}/scripts/install-hadoop-worker.sh")


  # 依赖关系：先创建子网和防火墙
  depends_on = [
    google_compute_subnetwork.spark_subnet,
    google_compute_firewall.spark_firewall
  ]
}
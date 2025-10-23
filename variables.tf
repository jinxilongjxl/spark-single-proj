variable "project_id" {
  description = "GCP项目ID"
  type        = string
}

variable "region" {
  description = "GCP区域"
  type        = string
  default     = "asia-east1"
}

variable "zone" {
  description = "GCP可用区"
  type        = string
  default     = "asia-east1-a"
}

variable "vpc_name" {
  description = "自定义VPC名称"
  type        = string
  default     = "spark-vpc"
}

variable "subnet_name" {
  description = "子网名称"
  type        = string
  default     = "spark-subnet"
}

variable "subnet_cidr" {
  description = "子网CIDR范围"
  type        = string
  default     = "10.0.0.0/24"  # 自定义IP段，避免与其他网络冲突
}

variable "vm_name" {
  description = "Spark虚拟机名称"
  type        = string
  default     = "spark-node"
}
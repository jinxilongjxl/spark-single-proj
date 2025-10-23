output "spark_external_ip" {
  description = "External IP of the Spark node"
  value       = google_compute_address.spark_ext_ip.address
}

output "spark_ssh_command" {
  description = "SSH into the Spark node"
  value       = "gcloud compute ssh ${google_compute_instance.spark_single.name} --project=${var.project_id} --zone=${var.zone}"
}

# 获取实例外部 IP（复用已有资源）
locals {
  spark_ip = google_compute_address.spark_ext_ip.address
}

output "spark_master_webui" {
  description = "Spark Master Web UI"
  value       = "http://${local.spark_ip}:8080"
}

output "spark_worker_webui" {
  description = "Spark Worker Web UI"
  value       = "http://${local.spark_ip}:8081"
}

output "spark_application_history" {
  description = "Spark History Server (if started)"
  value       = "http://${local.spark_ip}:18080"
}

output "spark_live_application_ui" {
  description = "Spark Driver Live Application UI (default when a job runs)"
  value       = "http://${local.spark_ip}:4040"
}

output "all_spark_ui_links" {
  description = "All Spark-related UI links in one map"
  value = {
    master_master   = "http://${local.spark_ip}:8080"
    worker          = "http://${local.spark_ip}:8081"
    live_app        = "http://${local.spark_ip}:4040"
    history_server  = "http://${local.spark_ip}:18080"
  }
}

output "ssh_spark_user_command" {
  description = "SSH into the instance as spark user (no sudo password)"
  value       = "gcloud compute ssh spark@${google_compute_instance.spark_single.name} --project=${var.project_id} --zone=${var.zone}"
}
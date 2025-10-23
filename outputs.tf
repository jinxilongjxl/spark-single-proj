output "vm_external_ip" {
  description = "Spark虚拟机公网IP（用于SSH和Web访问）"
  value       = google_compute_instance.spark_node.network_interface.0.access_config.0.nat_ip
}

output "vm_internal_ip" {
  description = "Spark虚拟机内部IP（VPC子网内）"
  value       = google_compute_instance.spark_node.network_interface.0.network_ip
}

output "ssh_command" {
  value = "ssh -i ~/.ssh/id_rsa hadoop@${google_compute_instance.hadoop_vm.network_interface[0].access_config[0].nat_ip}"
}

output "spark_master_web_ui" {
  description = "Spark Master Web界面地址"
  value       = "http://${google_compute_instance.spark_node.network_interface.0.access_config.0.nat_ip}:8080"
}
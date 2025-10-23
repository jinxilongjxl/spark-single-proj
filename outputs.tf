output "spark_external_ip" {
  description = "External IP of the Spark node"
  value       = google_compute_address.spark_ext_ip.address
}

output "spark_ssh_command" {
  description = "SSH into the Spark node"
  value       = "gcloud compute ssh ${google_compute_instance.spark_single.name} --project=${var.project_id} --zone=${var.zone}"
}
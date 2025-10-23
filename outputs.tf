output "vm_external_ip" {
  description = "Spark虚拟机公网IP"
  value       = google_compute_instance.spark_node.network_interface.0.access_config.0.nat_ip
}

output "spark_master_web_ui" {
  description = "Spark Master Web界面地址（通过浏览器访问）"
  value       = "http://${google_compute_instance.spark_node.network_interface.0.access_config.0.nat_ip}:8080"
}

output "ssh_command_ubuntu" {
  description = "通过默认ubuntu用户登录虚拟机（需管理员权限时使用）"
  value       = "ssh ubuntu@${google_compute_instance.spark_node.network_interface.0.access_config.0.nat_ip}"
}

output "ssh_command_spark" {
  description = "通过专用spark用户登录虚拟机（管理Spark时推荐使用）"
  value       = "ssh spark@${google_compute_instance.spark_node.network_interface.0.access_config.0.nat_ip}"
}

output "post_login_tips" {
  description = "登录spark用户后可执行的操作提示"
  value       = <<-EOT
    1. 验证Spark进程：jps（应显示Master和Worker）
    2. 提交测试任务：
       spark-submit --class org.apache.spark.examples.SparkPi \
         /opt/spark/examples/jars/spark-examples_2.13-4.0.1.jar 100
    3. 停止Spark服务：/opt/spark/sbin/stop-all.sh
  EOT
}
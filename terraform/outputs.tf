output "management_node" {
  value = "${google_compute_instance.management-instance.network_interface.0.access_config.0.assigned_nat_ip}"
}

output "management_user" {
  value = "${var.management_user}"
}

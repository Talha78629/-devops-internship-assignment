output "api_gateway_public_ip" {
  value = google_compute_instance.api_gateway.network_interface[0].access_config[0].nat_ip
}

output "api_gateway_private_ip" {
  value = google_compute_instance.api_gateway.network_interface[0].network_ip
}

output "python_worker_private_ip" {
  value = google_compute_instance.python_worker.network_interface[0].network_ip
}

output "typescript_worker_private_ip" {
  value = google_compute_instance.typescript_worker.network_interface[0].network_ip
}
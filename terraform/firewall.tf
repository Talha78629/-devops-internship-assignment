resource "google_compute_firewall" "allow_ssh_api" {
  name    = "allow-ssh-api"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = [var.ssh_source_ip]
  target_tags   = ["api-gateway"]
}

resource "google_compute_firewall" "allow_http_api" {
  name    = "allow-http-api"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80", "8080"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["api-gateway"]
}

resource "google_compute_firewall" "allow_internal_rpc" {
  name    = "allow-internal-rpc"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["3000", "4000", "5000", "8000", "9000"]
  }

  source_ranges = ["10.10.1.0/24"]
}

resource "google_compute_firewall" "allow_iap_ssh" {
  name    = "allow-iap-ssh"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["api-gateway", "worker"]
}
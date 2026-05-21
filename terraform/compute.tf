resource "google_compute_router" "router" {
  name    = "quickstart-router"
  region  = var.region
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "quickstart-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

resource "google_compute_instance" "api_gateway" {
  name         = "api-gateway-vm"
  machine_type = "e2-micro"
  zone         = var.zone

  tags = ["api-gateway"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 20
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.private_subnet.id
    network_ip = "10.10.1.10"

    access_config {}
  }

  metadata_startup_script = file("${path.module}/startup-scripts/api-gateway.sh")
}

resource "google_compute_instance" "python_worker" {
  name         = "python-worker-vm"
  machine_type = "e2-micro"
  zone         = var.zone

  tags = ["worker"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 20
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.private_subnet.id
    network_ip = "10.10.1.20"
  }

  metadata_startup_script = file("${path.module}/startup-scripts/python-worker.sh")
}

resource "google_compute_instance" "typescript_worker" {
  name         = "typescript-worker-vm"
  machine_type = "e2-micro"
  zone         = var.zone

  tags = ["worker"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 20
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.private_subnet.id
    network_ip = "10.10.1.30"
  }

  metadata_startup_script = file("${path.module}/startup-scripts/typescript-worker.sh")
}
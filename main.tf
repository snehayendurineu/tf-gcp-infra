# Create VPC network
resource "google_compute_network" "vpc_main_network" {
  name                            = var.vpc_network_name
  auto_create_subnetworks         = var.vpc_network_auto_create_subnets
  routing_mode                    = var.vpc_network_routing_mode
  delete_default_routes_on_create = var.vpc_network_delete_default_routes
}

# Create subnet webapp
resource "google_compute_subnetwork" "webapp_subnet" {
  name          = var.webapp_subnet_name
  network       = google_compute_network.vpc_main_network.self_link
  ip_cidr_range = var.webapp_subnet_cidr
}

# Create subnet db
resource "google_compute_subnetwork" "db_subnet" {
  name          = var.db_subnet_name
  network       = google_compute_network.vpc_main_network.self_link
  ip_cidr_range = var.db_subnet_cidr
}

# Create route for webapp subnet
resource "google_compute_route" "webapp_route" {
  name             = var.webapp_route_name
  network          = google_compute_network.vpc_main_network.self_link
  dest_range       = "0.0.0.0/0"
  next_hop_gateway = "default-internet-gateway"
  priority         = 1000
  depends_on       = [google_compute_subnetwork.webapp_subnet]
}

resource "google_compute_firewall" "allow_http" {
  name    = "allow-http"
  network = google_compute_network.vpc_main_network.id

  direction = "INGRESS"
  priority  = 1000
  disabled  = false

  allow {
    protocol = "tcp"
    ports    = [var.http_port]
  }

  source_ranges = ["0.0.0.0/0"]
  //target_tags = ["http-server"]
}

resource "google_compute_firewall" "deny_ssh" {
  name    = "deny-ssh"
  network = google_compute_network.vpc_main_network.id

  direction = "INGRESS"
  priority  = 65534
  disabled  = false

  deny {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  //target_tags = ["http-server"]
}


resource "google_compute_instance" "vm-instance-1" {
  name         = "vm-instance-1"
  machine_type = "e2-medium"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = var.cusimage_name
      size  = 100
      type  = "pd-balanced"
    }
  }
  network_interface {
    network    = google_compute_network.vpc_main_network.self_link
    subnetwork = google_compute_subnetwork.webapp_subnet.self_link
    access_config {}
  }

  service_account {
    email  = var.srv-acct-email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }
  //tags = ["http-server"]
}

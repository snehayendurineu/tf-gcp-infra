# Create VPC network
resource "google_compute_network" "vpc_main_network" {
  name                            = var.vpc_network_name
  auto_create_subnetworks         = var.vpc_network_auto_create_subnets
  routing_mode                    = var.vpc_network_routing_mode
  delete_default_routes_on_create = var.vpc_network_delete_default_routes
}

# Create subnet webapp
resource "google_compute_subnetwork" "webapp_subnet" {
  project       = var.gcp_project
  name          = var.webapp_subnet_name
  network       = google_compute_network.vpc_main_network.self_link
  ip_cidr_range = var.webapp_subnet_cidr
}

# Create subnet db
resource "google_compute_subnetwork" "db_subnet" {
  project                  = var.gcp_project
  name                     = var.db_subnet_name
  network                  = google_compute_network.vpc_main_network.self_link
  ip_cidr_range            = var.db_subnet_cidr
  private_ip_google_access = true
}

# Create route for webapp subnet
resource "google_compute_route" "webapp_route" {
  project          = var.gcp_project
  name             = var.webapp_route_name
  network          = google_compute_network.vpc_main_network.self_link
  dest_range       = "0.0.0.0/0"
  next_hop_gateway = "default-internet-gateway"
  priority         = 1000
  depends_on       = [google_compute_subnetwork.webapp_subnet]
}

resource "google_compute_firewall" "accept_http" {
  project = var.gcp_project
  name    = "accept-http"
  network = google_compute_network.vpc_main_network.self_link

  direction = "INGRESS"
  priority  = 1000
  disabled  = false

  allow {
    protocol = "tcp"
    ports    = [var.http_port]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http-server"]
}

resource "google_compute_firewall" "reject_ssh" {
  project = var.gcp_project
  name    = "reject-ssh"
  network = google_compute_network.vpc_main_network.self_link

  direction = "INGRESS"
  priority  = 65534
  disabled  = false
  deny {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http-server"]
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
  metadata = {
    startup-script = <<-EOF
      #!/bin/bash
      echo "Password: ${random_password.password.result}" > /home/packer/sample.txt
      echo "${google_sql_database_instance.db_instance.ip_address.0.ip_address}" >> /home/packer/sample.txt
      echo "${google_sql_user.users.name}" >> /home/packer/sample.txt
      echo "${google_sql_database_instance.db_instance.connection_name}" >> /home/packer/sample.txt
      echo "DB_USER=${google_sql_user.users.name}" > /home/packer/.env
      echo "DB_PASSWORD=${random_password.password.result}" >> /home/packer/.env
      echo "DB_NAME=${var.db_name}" >> /home/packer/.env
      echo "DB_HOST=${google_sql_database_instance.db_instance.ip_address.0.ip_address}" >> /home/packer/.env
      echo "DB_DIALECT=mysql" >> /home/packer/.env
      EOF
  }
  service_account {
    email  = var.srv-acct-email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }
  tags = ["http-server"]
}

// Enable Private Services Access
resource "google_compute_global_address" "private_service_access_ip" {
  name          = var.private_service_access_ip_name
  address_type  = "INTERNAL"
  purpose       = "VPC_PEERING"
  network       = google_compute_network.vpc_main_network.self_link
  prefix_length = 24
}

resource "google_service_networking_connection" "private_vpc_connection" {
  provider = google

  network                 = google_compute_network.vpc_main_network.self_link
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_service_access_ip.name]
}

resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_id" "db_name_suffix" {
  byte_length = 4
}

resource "google_sql_database_instance" "db_instance" {
  provider = google

  name                = "dbinstance-${random_id.db_name_suffix.hex}"
  region              = var.gcp_region
  database_version    = var.db-version
  deletion_protection = false


  settings {
    tier      = "db-f1-micro"
    disk_type = "pd-ssd"
    disk_size = 100
    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = google_compute_network.vpc_main_network.self_link
      enable_private_path_for_google_cloud_services = true
    }
    backup_configuration {
      enabled            = true
      binary_log_enabled = true
    }
    availability_type = var.db-availability-type
  }
}

resource "google_sql_database" "database" {
  name     = var.database
  instance = google_sql_database_instance.db_instance.name
}

resource "google_sql_user" "users" {
  name     = var.db-user
  instance = google_sql_database_instance.db_instance.name
  password = random_password.password.result
}

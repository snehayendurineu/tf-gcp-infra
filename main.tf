# Create VPC network
resource "google_compute_network" "vpc_main_network" {
  name = var.vpc_network_name
  auto_create_subnetworks = var.vpc_network_auto_create_subnets
  routing_mode = var.vpc_network_routing_mode
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
  name                  = var.webapp_route_name
  network               = google_compute_network.vpc_main_network.self_link
  dest_range            = "0.0.0.0/0"
  next_hop_gateway      = "default-internet-gateway"
  priority              = 1000
  tags                  = [var.webapp_subnet_name]
}


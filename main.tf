resource "google_compute_network" "vpc_main_network" {
  name                            = var.vpc_network_name
  auto_create_subnetworks         = var.vpc_network_auto_create_subnets
  routing_mode                    = var.vpc_network_routing_mode
  delete_default_routes_on_create = var.vpc_network_delete_default_routes
}

resource "google_compute_subnetwork" "webapp_subnet" {
  project       = var.gcp_project
  name          = var.webapp_subnet_name
  network       = google_compute_network.vpc_main_network.self_link
  ip_cidr_range = var.webapp_subnet_cidr
}

resource "google_compute_subnetwork" "db_subnet" {
  project                  = var.gcp_project
  name                     = var.db_subnet_name
  network                  = google_compute_network.vpc_main_network.self_link
  ip_cidr_range            = var.db_subnet_cidr
  private_ip_google_access = true
}

resource "google_compute_route" "webapp_route" {
  project          = var.gcp_project
  name             = var.webapp_route_name
  network          = google_compute_network.vpc_main_network.self_link
  dest_range       = "0.0.0.0/0"
  next_hop_gateway = "default-internet-gateway"
  priority         = 1000
  depends_on       = [google_compute_subnetwork.webapp_subnet]
}

resource "google_compute_firewall" "accept_https" {
  project = var.gcp_project
  name    = "accept-https"
  network = google_compute_network.vpc_main_network.self_link

  direction = "INGRESS"
  priority  = 1000
  disabled  = false

  allow {
    protocol = "tcp"
    ports    = [var.http_port]
  }

  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
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

resource "google_service_account" "logging_service_account" {
  account_id                   = "logging-srv-acct"
  display_name                 = "Logging Service Account"
  create_ignore_already_exists = true
  project                      = var.gcp_project
}

resource "google_project_iam_binding" "project_role_logAdmin" {
  project = var.gcp_project
  role    = "roles/logging.admin"

  members = [
    "serviceAccount:${google_service_account.logging_service_account.email}",
  ]
}

resource "google_project_iam_binding" "project_role_Monitoring" {
  project = var.gcp_project
  role    = "roles/monitoring.metricWriter"

  members = [
    "serviceAccount:${google_service_account.logging_service_account.email}",
  ]
}

resource "google_compute_health_check" "webapp_health_check" {
  name        = var.webapp_health_check_name
  description = "Health check via http"

  timeout_sec        = var.health_check_timeout
  check_interval_sec = var.health_check_interval
  healthy_threshold  = var.health_check_healthythreshold
  project            = var.gcp_project

  http_health_check {
    port         = var.http_port
    request_path = var.health_check_req_path
    proxy_header = "NONE"
  }

  log_config {
    enable = true
  }
}

resource "google_compute_instance_template" "webapp_instance_template" {
  name        = var.webapp_instance_template_name
  description = "This template is used to create app server instances."

  instance_description = "Template for VM instances needed"
  machine_type         = var.vm_machine_type
  can_ip_forward       = false

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
    provisioning_model  = "STANDARD"
  }
  disk {
    source_image = var.cusimage_name
    auto_delete  = true
    boot         = true
    type         = "pd-balanced"
    disk_size_gb = 100
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
    email  = google_service_account.logging_service_account.email
    scopes = ["cloud-platform"]
  }

  tags = ["http-server"]
}

resource "google_compute_instance_group_manager" "webapp_instance_group_manager" {
  name = var.webapp_instance_group_manager_name

  base_instance_name = "webapp-vm"
  zone               = var.zoneb

  version {
    instance_template = google_compute_instance_template.webapp_instance_template.self_link
  }

  target_size = 3

  named_port {
    name = "http"
    port = var.http_port
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.webapp_health_check.self_link
    initial_delay_sec = 300
  }

  update_policy {
    minimal_action        = "RESTART"
    type                  = "OPPORTUNISTIC"
    max_unavailable_fixed = 3
  }

  instance_lifecycle_policy {
    force_update_on_repair    = "NO"
    default_action_on_failure = "REPAIR"
  }

  depends_on = [google_compute_instance_template.webapp_instance_template]

}

resource "google_compute_autoscaler" "autoscaler_webapp" {
  name   = var.autoscaler_webapp_name
  target = google_compute_instance_group_manager.webapp_instance_group_manager.id
  zone   = var.zoneb

  autoscaling_policy {
    max_replicas    = var.autoscaler_max_rep
    min_replicas    = var.autoscaler_min_rep
    cooldown_period = var.autoscaler_cooldown_period

    cpu_utilization {
      target            = var.autoscaler_cpu_utilization
      predictive_method = "NONE"
    }
    mode = "ON"

  }


  depends_on = [google_compute_instance_group_manager.webapp_instance_group_manager]
}

resource "google_compute_backend_service" "lb_backend" {
  name                  = var.lb_backend_name
  load_balancing_scheme = "EXTERNAL"
  health_checks         = [google_compute_health_check.webapp_health_check.id]
  protocol              = "HTTP"
  session_affinity      = "NONE"
  timeout_sec           = 30
  log_config {
    enable = true
  }
  backend {
    group           = google_compute_instance_group_manager.webapp_instance_group_manager.instance_group
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }
}

resource "google_compute_url_map" "lb_url_mapping" {
  name            = var.lb_url_mapping_name
  default_service = google_compute_backend_service.lb_backend.id
  depends_on      = [google_compute_backend_service.lb_backend]
}

resource "google_compute_managed_ssl_certificate" "lb_ssl" {
  name = var.lb_ssl_name

  managed {
    domains = ["snehayenduri.me"]
  }
}

resource "google_compute_target_https_proxy" "lb_https_proxy" {
  name             = var.lb_https_proxy_name
  url_map          = google_compute_url_map.lb_url_mapping.id
  ssl_certificates = [google_compute_managed_ssl_certificate.lb_ssl.id]
  depends_on       = [google_compute_managed_ssl_certificate.lb_ssl]
}

resource "google_compute_global_forwarding_rule" "lb_frontend" {
  name = var.lb_frontend_name

  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL"
  port_range            = "443"
  target                = google_compute_target_https_proxy.lb_https_proxy.id
}

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
  special          = false
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
  depends_on = [google_service_networking_connection.private_vpc_connection]
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


data "google_dns_managed_zone" "dns_zone" {
  name = var.dns_zone
}

resource "google_dns_record_set" "dns_update" {
  managed_zone = var.dns_zone
  name         = data.google_dns_managed_zone.dns_zone.dns_name
  type         = "A"
  rrdatas      = [google_compute_global_forwarding_rule.lb_frontend.ip_address]
  ttl          = 120
  depends_on   = [google_compute_global_forwarding_rule.lb_frontend]
}


resource "google_storage_bucket" "cloud_func_bucket" {
  name     = var.cloud_func_bucket_name
  location = "US"
}

resource "google_storage_bucket_object" "cloud_func_bucket_obj" {
  name   = var.cloud_object_name
  bucket = google_storage_bucket.cloud_func_bucket.name
  source = var.cloud_object_source
}

resource "google_cloudfunctions2_function" "verify_email_cloudfunction" {
  name        = var.cloud_func_name
  description = "sends verification email for new users"
  location    = var.gcp_region
  project     = var.gcp_project

  build_config {
    runtime     = "nodejs20"
    entry_point = var.cloud_func_entrypoint
    source {
      storage_source {
        bucket = google_storage_bucket.cloud_func_bucket.name
        object = google_storage_bucket_object.cloud_func_bucket_obj.name
      }
    }
  }
  service_config {
    available_memory      = "128Mi"
    min_instance_count    = 0
    max_instance_count    = 1
    service_account_email = google_service_account.logging_service_account.email
    vpc_connector         = google_vpc_access_connector.vpc_access_connector.self_link
    environment_variables = {
      DB_USER     = google_sql_user.users.name
      DB_PASSWORD = random_password.password.result
      DB_NAME     = var.db_name
      DB_HOST     = google_sql_database_instance.db_instance.ip_address.0.ip_address
      DB_DIALECT  = "mysql"

    }
  }

  event_trigger {
    trigger_region = var.gcp_region
    event_type     = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic   = google_pubsub_topic.verify_email_pubsubtopic.id
  }

  depends_on = [google_pubsub_topic.verify_email_pubsubtopic, google_vpc_access_connector.vpc_access_connector]

}

resource "google_cloudfunctions2_function_iam_member" "invoker" {
  project        = google_cloudfunctions2_function.verify_email_cloudfunction.project
  location       = google_cloudfunctions2_function.verify_email_cloudfunction.location
  cloud_function = google_cloudfunctions2_function.verify_email_cloudfunction.name
  role           = "roles/cloudfunctions.invoker"
  member         = "serviceAccount:${google_service_account.logging_service_account.email}"
}

resource "google_cloud_run_service_iam_member" "cloud_run_invoker" {
  project  = google_cloudfunctions2_function.verify_email_cloudfunction.project
  location = google_cloudfunctions2_function.verify_email_cloudfunction.location
  service  = google_cloudfunctions2_function.verify_email_cloudfunction.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.logging_service_account.email}"
}

resource "google_project_iam_binding" "cloudsql_client" {
  project = var.gcp_project
  role    = "roles/cloudsql.client"

  members = [
    "serviceAccount:${google_service_account.logging_service_account.email}",
  ]
}


resource "google_pubsub_topic" "verify_email_pubsubtopic" {
  name                       = var.pubsub_topic_name
  message_retention_duration = var.pubsub_msgretentiondur
  project                    = var.gcp_project
}
resource "google_pubsub_subscription" "cloud_func_subscription" {
  name  = var.cloud_func_subscription_name
  topic = google_pubsub_topic.verify_email_pubsubtopic.id

  ack_deadline_seconds = 180

  push_config {
    push_endpoint = google_cloudfunctions2_function.verify_email_cloudfunction.url

    attributes = {
      content_type = "application/json"
    }
  }
  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "100s"
  }

  depends_on = [google_cloudfunctions2_function.verify_email_cloudfunction, google_pubsub_topic.verify_email_pubsubtopic]
}



resource "google_project_iam_binding" "tokenCreator" {
  project = var.gcp_project
  role    = "roles/iam.serviceAccountTokenCreator"

  members = [
    "serviceAccount:${google_service_account.logging_service_account.email}",
  ]
}

resource "google_project_iam_binding" "pubsubpublisher" {
  project = var.gcp_project
  role    = "roles/pubsub.publisher"

  members = [
    "serviceAccount:${google_service_account.logging_service_account.email}",
  ]
}


data "google_iam_policy" "subscriptioneditor" {
  binding {
    role = "roles/editor"
    members = [
      "serviceAccount:${google_service_account.logging_service_account.email}",
    ]
  }
}

resource "google_pubsub_subscription_iam_policy" "editor" {
  subscription = var.cloud_func_subscription_name
  policy_data  = data.google_iam_policy.subscriptioneditor.policy_data

  depends_on = [google_pubsub_subscription.cloud_func_subscription]
}


data "google_iam_policy" "pubsubtopicviewer" {
  binding {
    role = "roles/viewer"
    members = [
      "serviceAccount:${google_service_account.logging_service_account.email}",
    ]
  }
}

resource "google_pubsub_topic_iam_policy" "policy" {
  project     = google_pubsub_topic.verify_email_pubsubtopic.project
  topic       = google_pubsub_topic.verify_email_pubsubtopic.name
  policy_data = data.google_iam_policy.pubsubtopicviewer.policy_data
}

data "google_iam_policy" "cloudFunctionViewer" {
  binding {
    role = "roles/viewer"
    members = [
      "serviceAccount:${google_service_account.logging_service_account.email}",
    ]
  }
}

resource "google_cloudfunctions2_function_iam_policy" "policy" {
  project        = google_cloudfunctions2_function.verify_email_cloudfunction.project
  location       = google_cloudfunctions2_function.verify_email_cloudfunction.location
  cloud_function = google_cloudfunctions2_function.verify_email_cloudfunction.name
  policy_data    = data.google_iam_policy.cloudFunctionViewer.policy_data
}

resource "google_vpc_access_connector" "vpc_access_connector" {
  name          = var.vpc_access_connector_name
  region        = var.gcp_region
  network       = google_compute_network.vpc_main_network.self_link
  ip_cidr_range = var.vpc_access_connector_cidr
}

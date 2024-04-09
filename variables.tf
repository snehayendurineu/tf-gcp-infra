variable "gcp_project" {

}
variable "gcp_region" {
  type    = string
  default = "us-east1"
}
variable "vpc_network_auto_create_subnets" {
}

variable "vpc_network_name" {}
variable "webapp_subnet_name" {}
variable "webapp_subnet_cidr" {}
variable "db_subnet_name" {}
variable "db_subnet_cidr" {}

variable "vpc_network_routing_mode" {
  type    = string
  default = "REGIONAL"
}
variable "webapp_route_name" {
  type    = string
  default = "webapp-route"
}

variable "vpc_network_delete_default_routes" {

}

variable "http_port" {
  type    = string
  default = "8080"
}

variable "cusimage_name" {
  type    = string
  default = "cusimage-nomysql"
}


variable "zoneb" {
  type    = string
  default = "us-east1-b"
}


variable "zonec" {
  type    = string
  default = "us-east1-c"
}


variable "zoned" {
  type    = string
  default = "us-east1-d"
}

variable "srv-acct-email" {
  type    = string
  default = "pkr-serv-acct@cloud6225-dev.iam.gserviceaccount.com"
}


variable "db-version" {
  type    = string
  default = "MYSQL_8_0"
}


variable "db_name" {
  type    = string
  default = "webapp"
}

variable "private_service_access_ip_name" {
  type    = string
  default = "global-psconnect-ip"
}

variable "db-availability-type" {
  type    = string
  default = "REGIONAL"
}

variable "database" {
  type    = string
  default = "webapp"
}

variable "db-user" {
  type    = string
  default = "webapp"
}

variable "dns_zone" {
  type    = string
  default = "dns-zone-dev"
}

variable "pubsub_topic_name" {
  type    = string
  default = "verify_email"
}

variable "pubsub_msgretentiondur" {
  type    = string
  default = "604800s"
}

variable "cloud_func_name" {
  type    = string
  default = "verify-email-function"
}

variable "cloud_func_subscription_name" {
  type    = string
  default = "cloud-func-subscription"
}

variable "cloud_func_bucket_name" {
  type    = string
  default = "cloud_func_bucket_002859637"
}

variable "cloud_object_source" {
  type    = string
  default = "Archive.zip"
}

variable "cloud_func_entrypoint" {
  type    = string
  default = "helloPubSub"
}

variable "cloud_object_name" {
  type    = string
  default = "objects"
}

variable "vpc_access_connector_name" {
  type    = string
  default = "vpc-access-connector"
}

variable "vpc_access_connector_cidr" {
  type    = string
  default = "10.0.3.0/28"
}

variable "health_check_timeout" {
  type    = number
  default = 5
}

variable "health_check_interval" {
  type    = number
  default = 5
}

variable "health_check_healthythreshold" {
  type    = number
  default = 2
}

variable "health_check_unhealthythreshold" {
  type    = number
  default = 2
}

variable "health_check_req_path" {
  type    = string
  default = "/healthz"
}

variable "webapp_instance_template_name" {
  type    = string
  default = "webapp-instance-template"
}

variable "vm_machine_type" {
  type    = string
  default = "e2-standard-2"
}

variable "webapp_instance_group_manager_name" {
  type    = string
  default = "webapp-instance-group-manager"
}

variable "distribution_policy_target_shape" {
  type    = string
  default = "EVEN"
}

variable "autoscaler_webapp_name" {
  type    = string
  default = "autoscaler-webapp"
}

variable "autoscaler_max_rep" {
  type    = number
  default = 6
}

variable "autoscaler_min_rep" {
  type    = number
  default = 3
}

variable "autoscaler_cpu_utilization" {
  type    = number
  default = 0.05
}

variable "autoscaler_cooldown_period" {
  type    = number
  default = 60
}

variable "lb_backend_name" {
  type    = string
  default = "lb-backend"
}

variable "lb_url_mapping_name" {
  type    = string
  default = "webapp-loadbalancer"
}

variable "lb_https_proxy_name" {
  type    = string
  default = "lb-https-proxy"
}

variable "lb_frontend_name" {
  type    = string
  default = "lb-frontend"
}

variable "lb_ssl_name" {
  type    = string
  default = "lb-ssl"
}

variable "webapp_health_check_global_name" {
  type    = string
  default = "webapp-health-check-global"
}

variable "webapp_key_ring_name" {
  type    = string
  default = "webapp-key-ring"
}

variable "webapp_key_rotation_period" {
  type    = string
  default = "2592000s"
}

variable "webapp_key_vm_name" {
  type    = string
  default = "webapp-key-vm"
}

variable "webapp_key_sql_name" {
  type    = string
  default = "webapp-key-sql"
}

variable "webapp_key_storage_name" {
  type    = string
  default = "webapp-key-storage"
}

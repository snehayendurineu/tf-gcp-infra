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


variable "zone" {
  type    = string
  default = "us-east1-b"
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

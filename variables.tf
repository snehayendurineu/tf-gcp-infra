variable "gcp_project" {

}
variable "gcp_region" {

}
variable "vpc_network_auto_create_subnets" {

}

variable "vpc_network_name" {}
variable "webapp_subnet_name" {}
variable "webapp_subnet_cidr" {}
variable "db_subnet_name" {}
variable "db_subnet_cidr" {}

variable "vpc_network_routing_mode" {

}
variable "webapp_route_name" {

}

variable "vpc_network_delete_default_routes" {

}

variable "http_port" {
  type    = string
  default = "8080"
}

variable "cusimage_name" {
  type    = string
  default = "custom-cosimage"
}


variable "zone" {
  type    = string
  default = "us-east1-b"
}

variable "srv-acct-email" {
  type    = string
  default = "pkr-serv-acct@cloud6225-dev.iam.gserviceaccount.com"
}
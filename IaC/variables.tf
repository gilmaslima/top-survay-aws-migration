variable "region" {
  type    = string
  default = "us-east-1"
}

variable "db_name" {
  type    = string
  default = "topsurveydb"
}

variable "db_username" {
  type    = string
  default = "admin"
}

variable "db_password" {
  type    = string
  default = "strong_password"
}


variable "cluster_name" {
  type    = string
  default = "prod-topsuervey-eks-cluster"
}

variable "cluster_version" {
  type    = string
  default = "1.29"
}

variable "desired_capacity" {
  type    = number
  default = 4
}
variable "max_capacity" {
  type    = number
  default = 6
}

variable "min_capacity" {
  type    = number
  default = 2
}

variable "node_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "network_load_balancer_name" {
  type    = string
  default = "prod-topsurvey-nlb"
}


# input variables for the aws module, defaults are picked to keep the bill small
variable "aws_region" {
  description = "aws region to deploy into"
  type        = string
  default     = "eu-central-1"
}

variable "cluster_name" {
  description = "crewmeister cluster"
  type        = string
  default     = "crewmeister-challenge"
}

variable "kubernetes_version" {
  description = "eks control plane kubernetes version"
  type        = string
  default     = "1.34"
}

# t3.small keeps this cheap, bump it up if the app needs more headroom
variable "node_instance_type" {
  type    = string
  default = "t3.small"
}

variable "node_desired_size" {
  type    = number
  default = 1
}

variable "node_min_size" {
  type    = number
  default = 1
}

variable "node_max_size" {
  type    = number
  default = 2
}

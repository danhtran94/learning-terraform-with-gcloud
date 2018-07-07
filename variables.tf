# General vars
variable "ssh_user" {
  default = "ubuntu"
}

variable "public_key_path" {
  default = "/Users/danhtran94/.ssh/id_rsa.pub"
}

variable "private_key_path" {
  default = "/Users/danhtran94/.ssh/id_rsa"
}

variable "docker_api_ip" {
  default = "0.0.0.0"
}

# GCE Specific Vars
variable "worker_instance_count" {
  default = 1
}

variable "gce_creds_path" {
  default = "/Users/danhtran94/crazy-rapid-01021994-633312c77c77.json"
}

variable "manager_instance_count" {
  default = 1
}

variable "gce_project" {
  default = "crazy-rapid-01021994"
}

variable "gce_region" {
  default = "asia-southeast1"
}

variable "gce_instance_size" {
  default = "f1-micro"
}

variable "machine_image" {
  default = "ubuntu-os-cloud/ubuntu-1604-lts"
}

variable "docker_version" {
  default = "18.03.0~ce-0~ubuntu"
}

variable "management_ip_range" {
  default = "0.0.0.0/0"
}

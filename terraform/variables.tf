variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "zone" {
  type    = string
  default = "us-central1-a"
}

variable "ssh_source_ip" {
  type        = string
  description = "Your public IP in CIDR format, example 49.x.x.x/32"
}
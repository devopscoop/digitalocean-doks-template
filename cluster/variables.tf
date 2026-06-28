# Don't set defaults in this file; set them in terraform.tfvars so all values are in a single location.

variable "bucket" {
  type        = string
  description = "Spaces bucket holding OpenTofu state. Recommended naming scheme is $${cluster_name}-tofu-state (the bootstrap step creates it)."
}
variable "cluster_name" {
  type        = string
  description = "Recommended naming scheme is $${project}-$${environment}"
}
variable "org_name" {
  type        = string
  description = "Organization name, used to prefix globally-unique resource names such as Spaces buckets."
}
variable "kubernetes_version" {
  type        = string
  description = "DOKS version slug, e.g. \"1.32.2-do.0\". Leave empty (\"\") to use the latest version DigitalOcean offers. Run ./update_doks_version.sh to pin the latest."
}
variable "region" {
  type        = string
  description = "DigitalOcean region slug (e.g. nyc3). Must offer both DOKS and Spaces."
}
variable "vpc_cidr" {
  type        = string
  description = "Private IPv4 range for the cluster's VPC, in CIDR notation."
}
variable "node_size" {
  type        = string
  description = "Droplet size slug for the worker node pool (e.g. s-2vcpu-4gb). Run `doctl kubernetes options sizes` to list options."
}
variable "node_count" {
  type        = string
  description = "Number of nodes in the worker node pool."
}
variable "ha_control_plane" {
  type        = bool
  description = "Run the DOKS control plane in high-availability mode. Recommended for production; adds a fixed monthly cost."
}
variable "enable_dns" {
  type        = bool
  description = "Manage a DigitalOcean DNS domain for this cluster. external-dns and cert-manager (deployed via Flux) authenticate to the DO DNS API with a token."
}
variable "create_dns_zone" {
  type        = bool
  default     = true
  description = "When enable_dns is true, create the domain (true) or look up an existing one (false)."
}
variable "zone_name" {
  type        = string
  description = "DNS domain name, e.g. project1-dev.devops.coop."
}
variable "enable_container_registry" {
  type        = bool
  description = "Create a DigitalOcean Container Registry (DOCR). NOTE: DOCR is account-wide (one per account), so enable this on only one cluster per account."
}
variable "loki_noncurrent_version_expiration_days" {
  type        = number
  description = "How long to keep superseded (noncurrent) versions of objects in the Loki Spaces buckets before expiring them."
}
variable "tags" {
  type        = list(string)
  description = "Tags applied to the DOKS cluster and node pool so we can tell which repo created our resources. DigitalOcean tags are flat strings, not key/value pairs."
}

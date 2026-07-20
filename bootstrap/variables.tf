variable "cluster_name" {
  description = "The DigitalOcean Kubernetes (DOKS) cluster name."
  type        = string
}
variable "region" {
  description = "DigitalOcean region slug (e.g. nyc3). Must be a region that offers Spaces."
  type        = string
}

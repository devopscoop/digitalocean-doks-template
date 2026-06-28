# Container registry (replaces the AWS template's image-reflector-controller.tf).
#
# On AWS, the Flux image-reflector-controller reads ECR tags via an IRSA role.
# DigitalOcean's registry (DOCR) is account-wide - there is exactly one per
# account - so it is NOT a per-cluster resource. Enable this on a single cluster
# in the account (or manage the registry elsewhere and leave this disabled).
#
# Flux's image-reflector-controller and the cluster's nodes authenticate to DOCR
# using docker credentials derived from a DigitalOcean API token (a dockerconfig
# Secret managed in fluxcd-template), not IRSA.
resource "digitalocean_container_registry" "this" {
  count = var.enable_container_registry ? 1 : 0

  # DOCR names are globally unique across all of DigitalOcean, so prefix with the
  # org name.
  name                   = var.org_name
  subscription_tier_slug = "basic"
  region                 = var.region
}

output "container_registry_endpoint" {
  description = "DOCR endpoint, e.g. registry.digitalocean.com/<org>. Use it as the image registry in your Flux image automation."
  value       = one(digitalocean_container_registry.this[*].endpoint)
}

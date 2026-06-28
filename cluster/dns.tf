# DNS (replaces the AWS template's route53.tf).
#
# On AWS, cert-manager / external-dns authenticate to Route53 with IRSA roles
# created here. DigitalOcean has no IRSA: those controllers (deployed via
# fluxcd-template) authenticate to the DO DNS API with a DigitalOcean API token
# supplied as a Kubernetes Secret. So all this file manages is the DNS domain
# itself; there are no IAM roles to create.

resource "digitalocean_domain" "primary" {
  count = (var.enable_dns && var.create_dns_zone) ? 1 : 0
  name  = var.zone_name
}

data "digitalocean_domain" "primary" {
  count = (var.enable_dns && !var.create_dns_zone) ? 1 : 0
  name  = var.zone_name
}

locals {
  domain_name = var.enable_dns ? (
    var.create_dns_zone ? digitalocean_domain.primary[0].name : data.digitalocean_domain.primary[0].name
  ) : null
}

output "domain_name" {
  description = "Managed DNS domain. Configure external-dns/cert-manager in fluxcd-template to manage records under it."
  value       = local.domain_name
}

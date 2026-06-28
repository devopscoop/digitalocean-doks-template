provider "digitalocean" {}

locals {
  name   = var.cluster_name
  region = var.region

  # Pin kubernetes_version if set, otherwise track the latest DOKS release.
  kubernetes_version = var.kubernetes_version != "" ? var.kubernetes_version : data.digitalocean_kubernetes_versions.this.latest_version
}

################################################################################
# Network
################################################################################

# A dedicated VPC per cluster keeps node-to-node traffic on DigitalOcean's
# private network and isolates clusters from each other. The IPv4 range is the
# only network setting DOKS exposes; there is no public/private subnet split or
# NAT gateway to manage like there is in an AWS VPC - DOKS worker nodes reach the
# internet directly and the managed control plane lives outside the VPC.
resource "digitalocean_vpc" "this" {
  name     = local.name
  region   = local.region
  ip_range = var.vpc_cidr
}

################################################################################
# Cluster
################################################################################

# https://registry.terraform.io/providers/digitalocean/digitalocean/latest/docs/resources/kubernetes_cluster
#
# DOKS bundles a lot of what the AWS template wires up by hand:
#   - The control plane is fully managed (and its logs/metrics are handled by DO).
#   - A CNI, the DigitalOcean CSI driver (block storage), and the cloud
#     controller manager are preinstalled. A Service of type LoadBalancer
#     provisions a DigitalOcean Load Balancer automatically, so there is no
#     separate load-balancer-controller to install.
#   - Block storage volumes are encrypted at rest by DigitalOcean, so there is
#     no customer-managed KMS key to create.
resource "digitalocean_kubernetes_cluster" "this" {
  name     = local.name
  region   = local.region
  version  = local.kubernetes_version
  vpc_uuid = digitalocean_vpc.this.id

  # High-availability control plane for production resilience. This carries a
  # fixed monthly cost, so it's toggleable per cluster.
  ha = var.ha_control_plane

  # Surge upgrades spin up replacement nodes before draining old ones, avoiding
  # capacity dips during upgrades. auto_upgrade applies patch releases within
  # the maintenance window.
  surge_upgrade = true
  auto_upgrade  = true

  maintenance_policy {
    start_time = "05:00"
    day        = "sunday"
  }

  # Tear down associated load balancers and volumes on `tofu destroy` so the VPC
  # can be deleted without manual cleanup (the AWS template documents the
  # equivalent manual S3/CloudFormation cleanup).
  destroy_all_associated_resources = true

  node_pool {
    name       = "blue"
    size       = var.node_size
    node_count = var.node_count

    # Fixed-size pool (mirrors the AWS template's min=max=desired=3). Flip to
    # true and set min_nodes/max_nodes to let DOKS autoscale instead.
    auto_scale = false

    tags = var.tags
  }

  tags = var.tags
}

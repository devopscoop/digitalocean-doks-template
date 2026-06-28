# OpenTofu state lives in a single Spaces bucket: it's S3-compatible, so the
# OpenTofu `s3` backend can target it directly (see cluster/versions.tf), and
# state locking is handled by the backend's native conditional-write lockfile -
# no separate lock table is needed.
#
# We create a separate bucket per cluster so that `tofu apply` and
# `tofu destroy` for one cluster never touch another cluster's state.
#
# If you are using the subtree method you probably already have a state bucket -
# you can skip the bootstrap step entirely.
resource "digitalocean_spaces_bucket" "state" {
  name   = "${var.cluster_name}-tofu-state"
  region = var.region
  acl    = "private"

  # Keep historical state versions so a corrupted or accidentally-deleted state
  # file can be recovered.
  versioning {
    enabled = true
  }
}

output "bucket" {
  description = "Spaces bucket holding OpenTofu state. Set this as `bucket` in cluster/terraform.tfvars."
  value       = digitalocean_spaces_bucket.state.name
}

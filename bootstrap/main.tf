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

  # Objects in Spaces are encrypted at rest (AES-256) automatically; there is no
  # SSE argument to set. State can contain secrets, so the private ACL above is
  # what keeps it confidential.

  # Keep historical state versions so a corrupted or accidentally-deleted state
  # file can be recovered.
  versioning {
    enabled = true
  }

  # Deletion protection. force_destroy=false refuses to delete the bucket while
  # it still holds state objects; prevent_destroy makes `tofu destroy` (or any
  # plan that would replace/remove this bucket) error out. Losing the state
  # bucket means losing the ability to manage every cluster whose state lives
  # here, so this is intentionally hard to do by accident. To decommission for
  # real, remove this lifecycle block in a deliberate commit first.
  force_destroy = false
  lifecycle {
    prevent_destroy = true
  }
}

output "bucket" {
  description = "Spaces bucket holding OpenTofu state. Set this as `bucket` in cluster/terraform.tfvars."
  value       = digitalocean_spaces_bucket.state.name
}

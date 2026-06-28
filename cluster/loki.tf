################################################################################
# Loki (SingleBinary) Spaces storage
#
# The grafana/loki Helm chart in SingleBinary mode persists log chunks and the
# TSDB index to object storage, and stores ruler state in a second bucket. These
# map to loki.storage.bucketNames.chunks and loki.storage.bucketNames.ruler in
# the chart's values.
#
# DigitalOcean Spaces is S3-compatible, so Loki talks to it with its `s3`
# storage backend pointed at the Spaces endpoint. Loki authenticates with Spaces
# access keys (S3-style access_key_id / secret_access_key) supplied as a
# Kubernetes Secret in fluxcd-template - DigitalOcean has no IRSA, so there is no
# per-ServiceAccount IAM role to create here.
#
# Note on durability: the AWS template adds cross-region S3 replication for DR.
# Spaces has no cross-region replication feature, so that is intentionally
# omitted; Spaces already stores multiple redundant copies within a region. For
# cross-region DR you would replicate out-of-band (e.g. a scheduled `rclone`
# sync to a bucket in another region).
################################################################################

locals {
  # With org_name "devopscoop" and cluster_name "project1-dev", this yields the
  # "devopscoop-project1-dev-" bucket name prefix.
  loki_bucket_prefix = "${var.org_name}-${var.cluster_name}"

  loki_buckets = {
    chunks = "${local.loki_bucket_prefix}-loki-chunks"
    ruler  = "${local.loki_bucket_prefix}-loki-ruler"
  }
}

resource "digitalocean_spaces_bucket" "loki" {
  for_each = local.loki_buckets

  name   = each.value
  region = var.region
  acl    = "private"

  # Versioning bounds the blast radius of an accidental delete/overwrite. Loki
  # rewrites and compacts objects routinely, so the lifecycle rule below expires
  # superseded (noncurrent) versions to keep storage cost in check; the current
  # (live) version is never affected.
  versioning {
    enabled = true
  }

  lifecycle_rule {
    id      = "expire-noncurrent-versions"
    enabled = true

    noncurrent_version_expiration {
      days = var.loki_noncurrent_version_expiration_days
    }

    abort_incomplete_multipart_upload_days = 7
  }
}

output "loki_bucket_names" {
  description = "Loki Spaces bucket names. Set these as loki.storage.bucketNames.{chunks,ruler} in the loki Helm values in fluxcd-template."
  value       = { for k, b in digitalocean_spaces_bucket.loki : k => b.name }
}

output "loki_s3_endpoint" {
  description = "S3-compatible endpoint for the Loki Spaces buckets. Set as loki.storage.s3.endpoint (and region) in fluxcd-template."
  value       = "https://${var.region}.digitaloceanspaces.com"
}

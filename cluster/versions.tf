terraform {
  required_version = "1.12.2"
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }

  # DigitalOcean Spaces is S3-compatible, so OpenTofu's native `s3` backend
  # stores state there. We point it at the Spaces regional endpoint and skip the
  # AWS-specific preflight checks that don't apply to Spaces.
  #
  # OpenTofu (unlike Terraform) allows variables in backend blocks, which is why
  # these can reference var.* instead of being hardcoded.
  #
  # Credentials come from the AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY
  # environment variables, which must be set to your Spaces access keys (the s3
  # backend only reads the AWS_* names, not SPACES_*).
  backend "s3" {
    bucket = var.bucket
    key    = "${var.cluster_name}/terraform.tfstate"

    # Spaces ignores the region, but the s3 backend requires a value.
    region = var.region

    endpoints = {
      s3 = "https://${var.region}.digitaloceanspaces.com"
    }

    # State locking via the backend's native conditional-write lockfile; Spaces
    # has no DynamoDB equivalent.
    use_lockfile = true

    # Spaces is not AWS, so disable the AWS-only validation/lookups.
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
  }
}

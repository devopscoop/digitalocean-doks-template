# The DigitalOcean provider authenticates from environment variables, so no
# secrets live in this file:
#
#   - DIGITALOCEAN_TOKEN          - personal access token (DO API)
#   - SPACES_ACCESS_KEY_ID        - Spaces access key (S3-compatible)
#   - SPACES_SECRET_ACCESS_KEY    - Spaces secret key (S3-compatible)
#
# DigitalOcean has no per-provider region setting; region is set on each resource
# instead.
provider "digitalocean" {}

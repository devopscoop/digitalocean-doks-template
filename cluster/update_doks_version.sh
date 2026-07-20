#!/usr/bin/env bash

# Pins kubernetes_version in terraform.tfvars to the latest DOKS release.
# DOKS has no add-ons to version (the CNI/CSI/CCM are managed by DigitalOcean).
#
# Requires doctl, authenticated via `doctl auth init`.

# https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/
# Not using "-x" because we aren't debugging.
set -Eeuo pipefail

# https://stackoverflow.com/questions/59895/how-do-i-get-the-directory-where-a-bash-script-is-located-from-within-the-script
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# The first row of `doctl kubernetes options versions` is the latest version
# slug (e.g. 1.32.2-do.0).
latest=$(doctl kubernetes options versions --output json | jq -r '.[0].slug')

sed -i.bak -E "s/^kubernetes_version[^=]*=[ \t]+['\"]?[^'\"]*['\"]?/kubernetes_version = \"${latest}\"/" "${SCRIPT_DIR}/terraform.tfvars"
rm "${SCRIPT_DIR}/terraform.tfvars.bak"

tofu fmt "${SCRIPT_DIR}/terraform.tfvars"

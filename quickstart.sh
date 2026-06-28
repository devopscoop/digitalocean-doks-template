#!/usr/bin/env bash

if [[ $# -ne 4 ]]; then
  cat <<EOF >&2

Usage:

  $0 cluster_name domain github_org region

For example:

  $0 project1-dev devops.coop devopscoop nyc3

EOF
  exit 1
fi

# https://stackoverflow.com/questions/59895/how-do-i-get-the-directory-where-a-bash-script-is-located-from-within-the-script
export SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Need to know the name of the top level dir in this git repo so we can copy GitHub workflow files to the right place.
export git_top_dir=$(git rev-parse --show-toplevel)

if [[ "${SCRIPT_DIR}" == "${git_top_dir}" ]]; then
  export method='fork'
else
  export method='subtree'
fi

#TODO: checkout that git is in a clean state?

export cluster_name=$1
export domain=$2
export github_org=$3
export region=$4

export EXCLUDES="--exclude-dir .git --exclude-dir .terraform --exclude LICENSE --exclude README.md --exclude quickstart.sh"

grep -rIl ${EXCLUDES} project1-dev "${SCRIPT_DIR}" | xargs perl -pi -e "s/project1-dev/${cluster_name}/g"
grep -rIl ${EXCLUDES} devops.coop "${SCRIPT_DIR}" | xargs perl -pi -e "s/devops.coop/${domain}/g"
grep -rIl ${EXCLUDES} devopscoop "${SCRIPT_DIR}" | xargs perl -pi -e "s/devopscoop/${github_org}/g"
grep -rIl ${EXCLUDES} nyc3 "${SCRIPT_DIR}" | xargs perl -pi -e "s/nyc3/${region}/g"

# DigitalOcean auth is supplied entirely through GitHub Actions secrets -
# DIGITALOCEAN_TOKEN and the Spaces keys - so there is nothing to substitute
# into the workflow.

if [[ "$method" == "subtree" ]]; then

  # Because this is a subtree, we need to copy the workflow to the root of the git repo for GitHub to use it. Adding $cluster_name to the filename to avoid a naming conflict.
  cp "${SCRIPT_DIR}/.github/workflows/opentofu.yml" "${git_top_dir}/.github/workflows/opentofu-${cluster_name}.yml"

  # Workflow paths need to be update to point to subtree directory (which is named $cluster_name)
  perl -pi -e "s# cluster# ${cluster_name}/cluster#" "${git_top_dir}/.github/workflows/opentofu-${cluster_name}.yml"

fi

# Your fork or subtree of this repo shouldn't have the devopscoop CODEOWNERS file.
rm "${SCRIPT_DIR}/CODEOWNERS"

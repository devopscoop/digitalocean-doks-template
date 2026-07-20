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

export EXCLUDES="--exclude-dir .git --exclude-dir .terraform --exclude LICENSE --exclude README.md --exclude quickstart.sh --exclude opentofu.yml --exclude AGENTS.md"

# xargs -r: skip perl entirely when grep finds nothing, so re-running the
# script after the placeholders are already replaced is a clean no-op.
grep -rIl ${EXCLUDES} project1-dev "${SCRIPT_DIR}" | xargs -r perl -pi -e "s/project1-dev/${cluster_name}/g"
grep -rIl ${EXCLUDES} devops.coop "${SCRIPT_DIR}" | xargs -r perl -pi -e "s/devops.coop/${domain}/g"
grep -rIl ${EXCLUDES} devopscoop "${SCRIPT_DIR}" | xargs -r perl -pi -e "s/devopscoop/${github_org}/g"
grep -rIl ${EXCLUDES} nyc3 "${SCRIPT_DIR}" | xargs -r perl -pi -e "s/nyc3/${region}/g"

# DigitalOcean auth is supplied entirely through GitHub Actions secrets -
# DIGITALOCEAN_TOKEN and the Spaces keys - so there is nothing to substitute
# into the workflow.

if [[ "$method" == "subtree" ]]; then

  # Path of the subtree directory relative to the git repo root. Don't assume
  # it's named $cluster_name - the subtree can be added at any prefix.
  export subtree_dir="${SCRIPT_DIR#"${git_top_dir}"/}"

  # Because this is a subtree, we need to copy the workflow to the root of the git repo for GitHub to use it. Adding $cluster_name to the filename to avoid a naming conflict.
  mkdir --parents "${git_top_dir}/.github/workflows"
  cp "${SCRIPT_DIR}/.github/workflows/opentofu.yml" "${git_top_dir}/.github/workflows/opentofu-${cluster_name}.yml"

  # Workflow paths need to be updated to point to the subtree directory:
  # the push/PR paths filters, the default working-directory, and the
  # working dir the PR-comment script reads plan/validate output from.
  perl -pi -e "
    s#- cluster/#- ${subtree_dir}/cluster/#;
    s#working-directory: cluster#working-directory: ${subtree_dir}/cluster#;
    s#'cluster'#'${subtree_dir}/cluster'#;
  " "${git_top_dir}/.github/workflows/opentofu-${cluster_name}.yml"

fi

# Your fork or subtree of this repo shouldn't have the devopscoop CODEOWNERS file.
rm -f "${SCRIPT_DIR}/CODEOWNERS"

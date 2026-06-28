# AGENTS.md

This file provides guidance to Claude Code (claude.ai/code) and other agents when working with code in this repository.

## What this is

A template for provisioning a production-ready DigitalOcean Kubernetes (DOKS) cluster with OpenTofu. It is consumed either by **forking** (one git repo per cluster) or via **`git subtree`** into an existing monorepo. DOKS provides a lot out of the box (CNI, CSI block storage, cloud controller manager / LoadBalancer, at-rest encryption), so the template stays small. In-cluster controllers (cert-manager, external-dns, Loki, Flux image automation) authenticate with a DO API token or Spaces keys supplied as Kubernetes Secrets, which are managed *out of this repo* in `fluxcd-template`.

## Commands

Use `tofu` (OpenTofu via `tenv`), never `terraform`. The required version is pinned in `*/versions.tf` (`required_version`).

```sh
# bootstrap/ — one-time, run locally, creates the Spaces state bucket
cd bootstrap && tofu init && tofu apply

# cluster/ — normally driven by CI/CD, but locally:
cd cluster && tofu init && tofu plan && tofu apply

# validate without a state backend (what CI does on the template repo)
tofu init -backend=false && tofu validate

tofu fmt -recursive          # formatting; CI runs `tofu fmt -recursive -check`
./cluster/update_doks_version.sh   # pins kubernetes_version in cluster/terraform.tfvars to latest (needs doctl + jq)
./quickstart.sh <cluster_name> <domain> <github_org> <region>   # find-and-replace template defaults
```

There is no test suite. Validation = `tofu fmt -check` + `tofu validate` + `tofu plan` (posted as a PR comment by CI).

## Required environment / auth

Two *separate* credential types — do not confuse them:
- **DO API token** → `DIGITALOCEAN_TOKEN` (the `digitalocean` provider reads this). In CI it comes from the `DIGITALOCEAN_ACCESS_TOKEN` secret.
- **Spaces access keys** (S3-style, distinct from the API token) → `SPACES_ACCESS_KEY_ID` / `SPACES_SECRET_ACCESS_KEY`.

Gotcha: the OpenTofu `s3` (Spaces) state backend **only reads `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`** (those are the credential env var names the `s3` backend hard-codes), not the `SPACES_*` names. When running locally you must also export the Spaces keys under those names.

## Architecture

Two independent OpenTofu root modules (no module nesting; each is applied separately):

- **`bootstrap/`** — creates one versioned, private `digitalocean_spaces_bucket` per cluster to hold state. State locking uses the `s3` backend's native conditional-write lockfile (`use_lockfile = true`) — there is no separate lock table. Its own state (`terraform.tfstate*`) is deliberately committed to the repo (force-added); this is the one exception to "never commit state," safe only because these files contain no secrets. Skip this entirely when using the subtree method into a repo that already has a bucket.
- **`cluster/`** — the actual cluster. State lives in the Spaces bucket via the `s3` backend in `versions.tf`. OpenTofu (unlike Terraform) permits `var.*` references inside the backend block, which is why `bucket`/`cluster_name`/`region` are variables there. Key files: `main.tf` (VPC + DOKS cluster + node pool), `dns.tf` (`digitalocean_domain`, toggle create-vs-data-source), `container-registry.tf` (DOCR — **account-wide, one per account**, so enable on only one cluster), `loki.tf` (two Spaces buckets for Loki chunks/ruler), `data.tf`, `outputs.tf`. Outputs feed downstream `fluxcd-template` app `values.yaml` (`loki_bucket_names`, `loki_s3_endpoint`, `domain_name`, `container_registry_endpoint`).

### CI/CD (`.github/workflows/opentofu.yml`)
Runs on push/PR touching `cluster/**`. PR → `tofu plan` posted as a PR comment; merge to `main` → `tofu apply`. Auth is GitHub Actions secrets. The workflow branches on `github.repository == 'devopscoop/digitalocean-doks-template'`: the **template repo** only lint/validates with `-backend=false` (it has no state bucket or secrets); **real cluster repos** run the full init/plan/apply. Preserve this guard when editing the workflow.

`ghaups-daily.yml` runs daily to pin GitHub Actions to commit SHAs (and Trivy-scan them), opening a PR via a GitHub App token. All actions in workflows are SHA-pinned — keep them that way.

## Conventions

- Template placeholder values that `quickstart.sh` rewrites: cluster name `project1-dev`, domain `devops.coop`, org `devopscoop`, region `nyc3`. Forks/subtrees run quickstart to substitute these; it also deletes `CODEOWNERS` and (for subtree) copies/rewrites the workflow to the repo root.
- `cluster/terraform.tfvars` and `bootstrap/terraform.tfvars` share `cluster_name`/`region` — keep them in sync.
- DigitalOcean tags are flat strings; resources are tagged with the source repo (`github.com/<org>/<cluster>`).
- The README's "Creating a cluster" section has a strict, ordered git/branch workflow (bootstrap → commit state → add `.github` via a separate branch merged first → then the cluster branch). Do not `git push` cluster code ahead of that sequence — premature pushes trigger CI errors or build a misconfigured cluster. Per global instructions, never commit/push/PR without asking.

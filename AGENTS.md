# AGENTS.md

This file provides guidance to coding agents working with code in this repository. It is the single source of truth — edit `AGENTS.md`; any other agent-instruction filename in this repo is a symlink to it.

## What this is

A template for provisioning a production-ready DigitalOcean Kubernetes (DOKS) cluster with OpenTofu. It is consumed either by **forking** (one git repo per cluster) or via **`git subtree`** into an existing monorepo. DOKS provides a lot out of the box (CNI, CSI block storage, cloud controller manager / LoadBalancer, at-rest encryption), so the template stays small. In-cluster controllers (cert-manager, external-dns, Loki, Flux image automation) authenticate with a DO API token or Spaces keys supplied as Kubernetes Secrets, which are managed *out of this repo* in `fluxcd-template`.

## Commands

Use `tofu` (OpenTofu via `tenv`), never `terraform`. Versions are pinned exactly (not as ranges) in both root modules — `required_version = "1.12.3"` and `digitalocean = "2.92.0"` in `bootstrap/versions.tf` and `cluster/versions.tf`. Bump them together and commit the regenerated `.terraform.lock.hcl`.

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

There is no test suite. Validation = `tofu fmt -check` + `tofu validate` + `tofu plan` (posted as a PR comment by CI). The CI `fmt` step is `continue-on-error`, so a formatting miss surfaces in the PR comment without failing the job — `validate`/`plan` failures do fail it.

## Required environment / auth

Two *separate* credential types — do not confuse them:
- **DO API token** → `DIGITALOCEAN_TOKEN` (the `digitalocean` provider reads this; both `provider "digitalocean" {}` blocks are empty by design). In CI it comes from the `DIGITALOCEAN_ACCESS_TOKEN` secret.
- **Spaces access keys** (S3-style, distinct from the API token) → `SPACES_ACCESS_KEY_ID` / `SPACES_SECRET_ACCESS_KEY`.

Gotcha: the OpenTofu `s3` (Spaces) state backend **only reads `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`** (those are the credential env var names the `s3` backend hard-codes), not the `SPACES_*` names. When running locally you must also export the Spaces keys under those names.

## Architecture

Two independent OpenTofu root modules (no module nesting; each is applied separately):

- **`bootstrap/`** — creates one versioned, private `digitalocean_spaces_bucket` per cluster to hold state. State locking uses the `s3` backend's native conditional-write lockfile (`use_lockfile = true`) — there is no separate lock table. The bucket carries `force_destroy = false` + `lifecycle { prevent_destroy = true }`, so *any* plan that would replace or remove it errors out; decommissioning requires deleting that lifecycle block in a deliberate commit first. Bootstrap's own state (`terraform.tfstate*`) is deliberately committed (force-added past `.gitignore`); this is the one exception to "never commit state," safe only because these files contain no secrets. Skip this module entirely when using the subtree method into a repo that already has a bucket.
- **`cluster/`** — the actual cluster. State lives in the Spaces bucket via the `s3` backend in `versions.tf`. OpenTofu (unlike Terraform) permits `var.*` references inside the backend block, which is why `bucket`/`cluster_name`/`region` are variables there. Key files: `main.tf` (VPC + DOKS cluster + node pool, `surge_upgrade`/`auto_upgrade`, `destroy_all_associated_resources = true`), `dns.tf` (`digitalocean_domain`, toggle create-vs-data-source), `container-registry.tf` (DOCR — **account-wide, one per account**, so enable on only one cluster), `loki.tf` (two Spaces buckets for Loki chunks/ruler), `monitoring.tf`, `data.tf`, `outputs.tf`.

### Outputs live next to their resources

`cluster/outputs.tf` holds only the cluster-level outputs (`configure_kubectl`, `cluster_id`, `cluster_endpoint`, `cluster_urn`). Everything else is declared in the file that creates it: `loki_bucket_names` / `loki_s3_endpoint` in `loki.tf`, `domain_name` in `dns.tf`, `container_registry_endpoint` in `container-registry.tf`, `bucket` in `bootstrap/main.tf`. Follow that pattern for new outputs. Those four feed downstream `fluxcd-template` app `values.yaml` files, so renaming one breaks a consumer outside this repo.

### Monitoring (`cluster/monitoring.tf`)

`digitalocean_monitor_alert` policies (CPU / memory / disk, `GreaterThan` over a 5m window) exist to give a SOC 2 CC7.2 / availability control ongoing evidence. They need nothing in-cluster — DO's agent ships on DOKS worker droplets. They target droplets by `var.tags`, the *same* tags `main.tf` puts on the node pool, so changing `tags` in `terraform.tfvars` silently re-targets (or orphans) the alerts. Notifications go to `var.alert_email` (required when enabled) plus an optional Slack webhook. DOKS does not expose Kubernetes API-server audit logs at all — that requirement cannot be satisfied from this repo, so don't add code attempting it.

### Variables convention

`variables.tf` deliberately declares **no defaults** ("set them in `terraform.tfvars` so all values are in a single location") — only `create_dns_zone`, `alert_slack_webhook_url`, and `alert_slack_channel` have them. A new variable without a default and without a `terraform.tfvars` entry breaks `tofu plan` for every consumer, so add both.

Globally-unique names are derived, not hardcoded: DOCR is named `var.org_name`, Loki buckets are `${org_name}-${cluster_name}-loki-{chunks,ruler}`, and the state bucket is `${cluster_name}-tofu-state`.

## CI/CD

**`.github/workflows/opentofu.yml`** — runs on push/PR touching `cluster/**`. PR → `tofu plan` posted as a PR comment; merge to `main` → `tofu apply` of the saved `plan.file`. Auth is GitHub Actions secrets. Every tofu step branches on `github.repository == 'devopscoop/digitalocean-doks-template'`: the **template repo** only lint/validates with `-backend=false` (it has no state bucket or secrets); **real cluster repos** run the full init/validate/plan/apply. Preserve this guard when editing the workflow. To destroy a cluster, add `-destroy` to the plan and apply lines.

Three lines in this workflow are rewritten by `quickstart.sh` in subtree mode — the `- cluster/` path filters, `working-directory: cluster`, and the `'cluster'` literal the github-script step reads plan/validate output from. If you change how the working directory is expressed, update the matching `perl -pi -e` substitutions in `quickstart.sh`.

**`.github/workflows/claude.yml`** (tag mode, fires on `@claude` mentions) and **`claude-code-review.yml`** (agent mode, fires on every PR). Both pin `--model claude-opus-5 --effort xhigh` so CI does not drift with CLI defaults. Two non-obvious constraints, both documented inline — read the comments before editing:
- The review workflow's `--allowed-tools` allowlist is **required**, not optional: passing a `prompt` puts the action in agent mode, and the inline-comment MCP server is only registered when the allowlist contains an `mcp__github_inline_comment__` entry. Without it the job reviews the code, has no way to report, and silently posts nothing.
- The `code-review` plugin is deliberately not used there: it reports via `ReportFindings`, which `claude-code-action` does not handle, so it costs money per PR and posts nothing.
- `claude.yml` has `contents: write` but no Bash allowlist, so Claude pushes a branch and returns a prefilled PR link for a human — it cannot open the PR itself. Raising permissions would remove that human step.

**`.github/workflows/ghaups-daily.yml`** — runs daily to pin GitHub Actions to commit SHAs (and Trivy-scan them), opening a PR via a GitHub App token.

**Other:** `.github/dependabot.yml` updates the `terraform` providers (both directories) and `github-actions` weekly. `.gitlab-ci.yml` runs GitLab SAST + secret detection for mirrored/GitLab consumers. All actions are SHA-pinned with a trailing `# vX` comment — keep them that way.

## Conventions

- Template placeholder values that `quickstart.sh` rewrites in place: cluster name `project1-dev`, domain `devops.coop`, org `devopscoop`, region `nyc3`. It skips `LICENSE`, `README.md`, `quickstart.sh`, `AGENTS.md`, and `opentofu.yml` — the workflow is excluded so the org rename cannot clobber the upstream-template guard string, and the docs are excluded so they keep describing the template. It also deletes `CODEOWNERS` and (for subtree) copies/rewrites the workflow to the repo root as `opentofu-<cluster_name>.yml`. Re-running it is a no-op.
- `cluster/terraform.tfvars` and `bootstrap/terraform.tfvars` share `cluster_name`/`region` — keep them in sync.
- DigitalOcean tags are flat strings, not key/value pairs; resources are tagged with the source repo (`github.com/<org>/<cluster>`).
- The README's "Creating a cluster" section has a strict, ordered git/branch workflow (bootstrap → commit state → add `.github` via a separate branch merged first → then the cluster branch). Do not `git push` cluster code ahead of that sequence — premature pushes trigger CI errors or build a misconfigured cluster. Per global instructions, never commit/push/PR without asking.

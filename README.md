# digitalocean-doks-template

This repo can be used to build a production-ready DigitalOcean Kubernetes (DOKS) cluster. It can either be forked, or included in a monorepo à la carte with `git subtree`.

## How this differs from aws-eks-template

This is the DigitalOcean counterpart to [aws-eks-template](../aws-eks-template). DigitalOcean's managed Kubernetes bundles a lot of what EKS makes you wire up by hand, so the template is considerably smaller:

| Concern | AWS EKS template | This DOKS template |
| --- | --- | --- |
| State backend | S3 bucket + DynamoDB lock table | Spaces bucket (S3-compatible) with native lockfile |
| CI/CD auth | GitHub OIDC role-to-assume (CloudFormation) | `DIGITALOCEAN_ACCESS_TOKEN` + Spaces keys as GitHub secrets |
| Networking | VPC with public/private subnets + NAT gateway | `digitalocean_vpc` (managed control plane lives outside it) |
| Storage CSI / snapshots | EBS/EFS CSI add-ons, KMS key, DLM snapshot policy | DigitalOcean CSI preinstalled; volumes encrypted at rest by default |
| Load balancing | aws-load-balancer-controller + IRSA | Built-in cloud controller manager; `Service type=LoadBalancer` provisions a DO LB |
| Workload identity | IRSA roles for cert-manager/external-dns/loki/image-reflector | No IRSA; controllers use a DO API token / Spaces keys (Kubernetes Secrets, managed in fluxcd-template) |
| DNS | Route53 hosted zone | `digitalocean_domain` |
| Container registry | ECR (per repo) | DOCR (account-wide - one per account) |
| Log storage | Loki on S3 + cross-region replication | Loki on Spaces (no cross-region replication; Spaces is intra-region redundant) |

## Prerequisites

- GitHub (TODO: update this repo to work with other git platforms)
- Do not install opentofu directly. Instead, use [tenv](https://github.com/tofuutils/tenv)
- [`doctl`](https://docs.digitalocean.com/reference/doctl/how-to/install/), the DigitalOcean CLI

## Onboarding

### Authenticate doctl

Create a personal access token in the DigitalOcean control panel (API → Tokens) with read/write scope, then:

```
doctl auth init
```

### Create Spaces access keys

The OpenTofu state backend (and Loki) talk to Spaces over the S3 API, which uses a separate **Spaces access key** pair - not the API token. Create one in the control panel (API → Spaces Keys), then export them. The provider reads these env vars:

```
export DIGITALOCEAN_TOKEN='dop_v1_...'
export SPACES_ACCESS_KEY_ID='...'
export SPACES_SECRET_ACCESS_KEY='...'
```

> **Note:** the OpenTofu `s3` backend only reads the `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` names for its credentials. When running locally, also export those set to your Spaces keys:
> ```
> export AWS_ACCESS_KEY_ID="$SPACES_ACCESS_KEY_ID"
> export AWS_SECRET_ACCESS_KEY="$SPACES_SECRET_ACCESS_KEY"
> ```

## Creating a cluster

> **WARNING**
> Don't `git push` any code unless there is an instruction to do so. If you push code too early, you will either get CI/CD pipeline errors, or you will accidentally build a misconfigured cluster.

### Prepare environment

1. Choose a name for your new cluster. TODO: add link to naming things is easy doc in branch of website repo.
1. Set some env vars for the quickstart.sh script, for example:
   ```
   export cluster_name='project1-dev'
   export domain='devops.coop'
   export github_org='devopscoop'
   export region='nyc3'
   export branch_name='create_cluster'
   ```
1. Choose an installation method - either Fork or Subtree:
   - Fork if you want a new git repo for this cluster:
      1. Click the "Fork" button in this repo to create a repo in your organization with the same name as the cluster you are creating.
      1. In GitHub, click on the Actions tab, then click the button to enable workflows.
      1. Create a branch:
         ```
         git checkout -b $branch_name
         ```
   - Subtree if you want to put this code in an existing infrastructure as code git repo:
      1. Change directory to your existing repo.
      1. Checkout a new branch, use subtree to add this repo to a subdirectory, then change directory to it:
         ```
         git checkout -b $branch_name
         git subtree add --prefix $cluster_name git@github.com:devopscoop/digitalocean-doks-template.git main
         cd $cluster_name
         ```

### Bootstrap

This creates a DigitalOcean Spaces bucket for OpenTofu's state files. State locking uses the `s3` backend's native conditional-write lockfile, so there is no separate lock table (the AWS template uses DynamoDB for this).

If you are using the subtree method, you probably already have a bucket - you can skip this section.

Process:

1. Change directory to `bootstrap`.
1. Verify that the values in `terraform.tfvars` are correct.
1. Make sure your `DIGITALOCEAN_TOKEN` and `SPACES_*` env vars are set (see Onboarding).
1. Initialize the repo:
   ```shell
   tofu init
   ```
1. Apply the code to create the Spaces bucket:
   ```shell
   tofu apply
   ```
1. Against our better judgement, commit the terraform.tfstate* files to the repo. This is normally SUPER-FORBIDDEN! State files often have cleartext secrets in them, and we NEVER want to commit secrets to the repo. However, these particular files don't have any secrets in them:
   ```shell
   git add -f terraform.tfstate*
   git commit -m "Bootstrapping OpenTofu"
   ```

### Configure CI/CD credentials

DigitalOcean has no OIDC role-assumption like AWS, so the pipeline authenticates with secrets. In your cluster's GitHub repo (Settings → Secrets and variables → Actions), create:

- `DIGITALOCEAN_ACCESS_TOKEN` - a DO API token (read/write).
- `SPACES_ACCESS_KEY_ID` - your Spaces access key.
- `SPACES_SECRET_ACCESS_KEY` - your Spaces secret key.

If you are using the subtree method, you probably already have these secrets - you can skip this section.

### DOKS Cluster

1. Run the quickstart.sh script to replace default values with your organization's values:
   ```
   ./quickstart.sh $cluster_name $domain $github_org $region
   ```
1. Edit the `cluster/terraform.tfvars` file. In particular, set `bucket` to the bootstrap output, pick a `node_size`/`node_count`, and either leave `kubernetes_version = ""` to track the latest or run `./cluster/update_doks_version.sh` to pin it.
1. Commit your changes, but don't push yet.
   ```
   git add -A
   git commit -m "Creating the cluster"
   ```
1. Change directory back to the top level of the git repo:
   ```
   cd $(git rev-parse --show-toplevel)
   ```
1. Checkout a new branch that's pointed at origin/main, which should be empty at this point:
  ```
  git checkout -b github_actions origin/main
  ```
1. Add the GitHub Actions file, commit, push:
  ```
  git checkout $branch_name .github
  git add .github
  git commit -m "Adding GitHub Actions so we can do the rest of the changes via GitOps."
  git push origin github_actions
  ```
1. Create a PR, and merge the branch to main.
1. Checkout the create_cluster branch again:
   ```
   git checkout $branch_name
   ```
1. Push it, create a PR, and Opentofu should create a comment on the PR with the output of a `tofu plan`.
1. If it looks good, merge it to the default branch to create your cluster.
1. Once the apply finishes, configure kubectl with the command from the `configure_kubectl` output:
   ```
   doctl kubernetes cluster kubeconfig save <cluster_name>
   ```
1. Wire the cluster outputs into your fluxcd-template apps' `values.yaml`:
   - `loki_bucket_names` / `loki_s3_endpoint` → the loki Helm values (`loki.storage.bucketNames.*`, `loki.storage.s3.endpoint`). Loki authenticates with your Spaces keys, supplied as a Kubernetes Secret.
   - `domain_name` → the external-dns / cert-manager apps (which authenticate to the DO DNS API with a DigitalOcean token Secret).
   - `container_registry_endpoint` → your Flux image automation (nodes/Flux pull from DOCR using a docker-credentials Secret derived from a DO token).

## Destroying a cluster

To destroy a cluster, add `-destroy` to the `tofu plan` and `tofu apply` lines in the `.github/workflows/opentofu.yml` file. Because the cluster sets `destroy_all_associated_resources = true`, its load balancers and volumes are removed automatically, so the VPC can be deleted.

The last thing to clean up is the bootstrap Spaces bucket. To destroy it, go to the bootstrap directory on your local laptop, and run:

```
tofu destroy
```

This will likely fail because the bucket isn't empty. Empty it (control panel, or `doctl`/`s3cmd`), then run `tofu destroy` again.

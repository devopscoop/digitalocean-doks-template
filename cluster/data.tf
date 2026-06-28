# DigitalOcean has no AWS-SSO equivalent: cluster access is granted via the
# kubeconfig token DigitalOcean mints for your API token, and Kubernetes RBAC is
# layered on inside the cluster (managed in fluxcd-template). So, unlike the AWS
# template, there are no IAM/SSO roles to discover here.

# Used to default kubernetes_version to the latest DOKS release when the
# variable is left empty.
data "digitalocean_kubernetes_versions" "this" {}

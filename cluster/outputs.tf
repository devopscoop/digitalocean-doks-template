output "configure_kubectl" {
  description = "Configure kubectl: make sure doctl is authenticated (doctl auth init), then run this to merge the cluster into your kubeconfig."

  # doctl writes a context/user named do-<region>-<cluster> into your kubeconfig
  # and sets it current. Pass --kubeconfig to keep it out of your default
  # ~/.kube/config if you juggle multiple clusters via the KUBECONFIG env var.
  value = "doctl kubernetes cluster kubeconfig save ${digitalocean_kubernetes_cluster.this.name}"
}

output "cluster_id" {
  description = "DOKS cluster UUID."
  value       = digitalocean_kubernetes_cluster.this.id
}

output "cluster_endpoint" {
  description = "DOKS API server endpoint."
  value       = digitalocean_kubernetes_cluster.this.endpoint
}

output "cluster_urn" {
  description = "DOKS cluster URN, handy for attaching the cluster to DigitalOcean projects/monitoring."
  value       = digitalocean_kubernetes_cluster.this.urn
}

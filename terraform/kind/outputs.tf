# prints the cluster's API endpoint after apply, useful for a sanity check
output "cluster_endpoint" {
  value = kind_cluster.this.endpoint
}

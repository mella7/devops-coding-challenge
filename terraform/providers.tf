# no config needed - the kind provider just talks to your local Docker
provider "kind" {}

# tells the helm provider how to reach the cluster kind just created,
# using the same credentials kind_cluster.this exposes
provider "helm" {
  kubernetes {
    host                   = kind_cluster.this.endpoint
    cluster_ca_certificate = kind_cluster.this.cluster_ca_certificate
    client_certificate     = kind_cluster.this.client_certificate
    client_key             = kind_cluster.this.client_key
  }
}

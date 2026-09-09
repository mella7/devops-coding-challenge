resource "helm_release" "app" {
  name  = "crewmeister"
  chart = "../helm/crewmeister-challenge"

  wait    = true
  timeout = 300

  depends_on = [kind_cluster.this]
}

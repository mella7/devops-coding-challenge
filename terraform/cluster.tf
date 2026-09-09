# creates the same local cluster you were making by hand with `kind create cluster`
resource "kind_cluster" "this" {
  name           = "crewmeister-challenge"
  wait_for_ready = true
}

#!/usr/bin/env bash
set -euo pipefail

# Brings the whole stack up from a fresh clone, in the only order that
# actually works: cluster first, then image, then the app. Terraform only
# owns the cluster - helm install happens here, after the image is loaded,
# to avoid a chicken-and-egg race between the two. Safe to re-run.

log() { echo "==> $*"; }

log "Building app image"
docker build -t crewmeister-challenge:local .

log "Provisioning the kind cluster via Terraform"
cd terraform/kind
terraform init -input=false
terraform apply -auto-approve
cd ..

log "Loading image into kind (registry-free local workflow)"
kind load docker-image crewmeister-challenge:local --name crewmeister-challenge

log "Installing the app via Helm"
helm upgrade --install crewmeister ./helm/crewmeister-challenge --wait --timeout 5m

log "Installing kube-prometheus-stack (Prometheus + Grafana)"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update >/dev/null
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace --wait --timeout 5m \
  -f monitoring/values-local.yaml \
  --set grafana.adminPassword=admin

log "Done. Try:"
echo "  kubectl port-forward svc/crewmeister-app 8080:8080"
echo "  kubectl port-forward svc/kube-prometheus-stack-grafana 3000:80 -n monitoring   (login: admin/admin)"

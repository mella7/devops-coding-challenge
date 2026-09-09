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
cd terraform
terraform init -input=false
terraform apply -auto-approve
cd ..

log "Loading image into kind (registry-free local workflow)"
kind load docker-image crewmeister-challenge:local --name crewmeister-challenge

log "Installing the app via Helm"
helm upgrade --install crewmeister ./helm/crewmeister-challenge --wait --timeout 5m

log "Done. Try:"
echo "  kubectl port-forward svc/crewmeister-app 8080:8080"
EOF

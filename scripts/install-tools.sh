#!/usr/bin/env bash
set -euo pipefail

# Installs/checks: docker, docker compose plugin, kind, kubectl, helm.
# Safe to re-run - skips anything already present.

log() { echo "==> $*"; }
have() { command -v "$1" >/dev/null 2>&1; }

# ---- OS / package manager detection ---------------------------------
OS="$(uname -s)"
PKG=""

case "$OS" in
  Linux)
    if have dnf; then PKG="dnf"
    elif have apt-get; then PKG="apt"
    elif have pacman; then PKG="pacman"
    else
      echo "No supported package manager found (dnf/apt/pacman). Install docker/kubectl manually." >&2
      exit 1
    fi
    ;;
  Darwin)
    if ! have brew; then
      echo "Homebrew not found. Install it first: https://brew.sh" >&2
      exit 1
    fi
    PKG="brew"
    ;;
  *)
    echo "Unsupported OS: $OS (this script targets Linux and macOS)" >&2
    exit 1
    ;;
esac

ARCH="$(uname -m)"
case "$ARCH" in
  x86_64|amd64) ARCH="amd64" ;;
  arm64|aarch64) ARCH="arm64" ;;
  *) echo "Unsupported architecture: $ARCH" >&2; exit 1 ;;
esac

log "Detected OS=$OS PKG=$PKG ARCH=$ARCH"

# ---- docker -----------------------------------------------------------
if have docker; then
  log "docker already installed: $(docker --version)"
else
  log "Installing docker"
  case "$PKG" in
    dnf) sudo dnf install -y docker ;;
    apt) sudo apt-get update && sudo apt-get install -y docker.io ;;
    pacman) sudo pacman -Sy --noconfirm docker ;;
    brew) brew install --cask docker ;;
  esac
  echo "docker installed - you may need to add your user to the docker group and re-login:"
  echo "  sudo usermod -aG docker \$USER"
fi

# ---- docker compose plugin ---------------------------------------------
if docker compose version >/dev/null 2>&1; then
  log "docker compose already installed: $(docker compose version)"
else
  log "Installing docker compose plugin"
  case "$PKG" in
    dnf) sudo dnf install -y docker-compose-plugin 2>/dev/null || true ;;
    apt) sudo apt-get install -y docker-compose-plugin 2>/dev/null || true ;;
    pacman) sudo pacman -Sy --noconfirm docker-compose 2>/dev/null || true ;;
    brew) : ;;  # ships with Docker Desktop on macOS
  esac
  if ! docker compose version >/dev/null 2>&1; then
    log "Package not available, installing compose as a CLI plugin binary"
    mkdir -p ~/.docker/cli-plugins
    COMPOSE_VERSION="v5.5.0"
    curl -SL "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-${ARCH}" \
      -o ~/.docker/cli-plugins/docker-compose
    chmod +x ~/.docker/cli-plugins/docker-compose
  fi
fi

# ---- kubectl -----------------------------------------------------------
if have kubectl; then
  log "kubectl already installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
else
  log "Installing kubectl"
  case "$PKG" in
    dnf) sudo dnf install -y kubectl ;;
    apt)
      curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${ARCH}/kubectl"
      chmod +x kubectl
      sudo mv kubectl /usr/local/bin/kubectl
      ;;
    pacman) sudo pacman -Sy --noconfirm kubectl ;;
    brew) brew install kubectl ;;
  esac
fi

# ---- kind -----------------------------------------------------------
if have kind; then
  log "kind already installed: $(kind --version)"
else
  log "Installing kind"
  if [ "$PKG" = "brew" ]; then
    brew install kind
  else
    curl -Lo /tmp/kind "https://kind.sigs.k8s.io/dl/latest/kind-linux-${ARCH}"
    chmod +x /tmp/kind
    sudo mv /tmp/kind /usr/local/bin/kind
  fi
fi

# ---- helm -----------------------------------------------------------
if have helm; then
  log "helm already installed: $(helm version --short)"
else
  log "Installing helm"
  if [ "$PKG" = "brew" ]; then
    brew install helm
  else
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  fi
fi

# ---- terraform -----------------------------------------------------------
if have terraform; then
  log "terraform already installed: $(terraform version | head -1)"
else
  log "Installing terraform"
  case "$PKG" in
    dnf)
      sudo dnf config-manager addrepo --from-repofile=https://rpm.releases.hashicorp.com/fedora/hashicorp.repo 2>/dev/null || true
      sudo dnf install -y terraform 2>/dev/null || true
      ;;
    apt)
      sudo apt-get install -y gnupg software-properties-common
      wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
      echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
        sudo tee /etc/apt/sources.list.d/hashicorp.list
      sudo apt-get update && sudo apt-get install -y terraform
      ;;
    pacman) sudo pacman -Sy --noconfirm terraform ;;
    brew) brew tap hashicorp/tap && brew install hashicorp/tap/terraform ;;
  esac

  if ! have terraform; then
    log "Repo install failed, falling back to direct binary download"
    TF_VERSION="1.9.8"
    curl -Lo /tmp/terraform.zip \
      "https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_$([ "$OS" = Darwin ] && echo darwin || echo linux)_${ARCH}.zip"
    unzip -o /tmp/terraform.zip -d /tmp
    sudo mv /tmp/terraform /usr/local/bin/terraform
  fi
fi

# ---- trivy -----------------------------------------------------------
if have trivy; then
  log "trivy already installed: $(trivy --version | head -1)"
else
  log "Installing trivy"
  case "$PKG" in
    dnf)
      sudo dnf install -y trivy 2>/dev/null || {
        cat <<REPO | sudo tee /etc/yum.repos.d/trivy.repo >/dev/null
[trivy]
name=Trivy repository
baseurl=https://aquasecurity.github.io/trivy-repo/rpm/releases/\$releasever/\$basearch/
gpgcheck=1
enabled=1
gpgkey=https://aquasecurity.github.io/trivy-repo/rpm/public.key
REPO
        sudo dnf install -y trivy
      }
      ;;
    apt)
      sudo apt-get install -y wget apt-transport-https gnupg
      wget -qO- https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo gpg --dearmor -o /usr/share/keyrings/trivy.gpg
      echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | \
        sudo tee /etc/apt/sources.list.d/trivy.list
      sudo apt-get update && sudo apt-get install -y trivy
      ;;
    pacman) sudo pacman -Sy --noconfirm trivy ;;
    brew) brew install trivy ;;
  esac
fi

log "All tools ready:"
docker --version
docker compose version
kubectl version --client --short 2>/dev/null || kubectl version --client
kind --version
helm version --short
terraform version

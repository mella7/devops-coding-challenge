# pins Terraform itself and the kind provider version.
# helm provider intentionally not used locally - see scripts/setup.sh for why.
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "~> 0.7"
    }
  }
}

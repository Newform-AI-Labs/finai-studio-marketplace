terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0, < 8.0"
    }
    google-beta = {
      source = "hashicorp/google-beta"
    }
    helm = {
      source = "hashicorp/helm"
      # Stay on 2.x (nested `kubernetes {}` block syntax) but allow the latest
      # 2.x — the exact old 2.8.0 artifact times out from the validator's mirror.
      version = ">= 2.12, < 3.0"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

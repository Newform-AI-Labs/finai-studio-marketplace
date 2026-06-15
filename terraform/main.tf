# =============================================================================
# FinAI Studio — Marketplace Terraform deployer (provider + project setup).
# Cluster wiring is in gke.tf; the Helm release is in helm.tf.
# The google provider block must live here — the Marketplace mpdev tooling
# injects the goog-partner-solution consumer-tracking label into it.
# =============================================================================

provider "google" {
  project = var.project_id
}

provider "google-beta" {
  project = var.project_id
}

data "google_client_config" "default" {}

resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

# =============================================================================
# Cluster wiring. For real installs (create_cluster=false) the module reads the
# customer's existing GKE cluster. For Marketplace validation
# (marketplace_test.tfvars sets create_cluster=true) it plans a new cluster so
# `terraform plan` succeeds without a pre-existing cluster (the endpoint is
# unknown at plan time, so the helm release is deferred to apply).
# =============================================================================

locals {
  endpoint       = var.create_cluster ? "https://${module.gke[0].endpoint}" : "https://${data.google_container_cluster.default[0].endpoint}"
  ca_certificate = var.create_cluster ? base64decode(module.gke[0].ca_certificate) : base64decode(data.google_container_cluster.default[0].master_auth[0].cluster_ca_certificate)
  host           = local.endpoint

  # Derive region/zonal from the cluster_location (e.g. "us-central1" vs "us-central1-a").
  is_regional = length(split("-", var.cluster_location)) == 2
  region      = local.is_regional ? var.cluster_location : join("-", slice(split("-", var.cluster_location), 0, 2))
  zones       = local.is_regional ? [] : [var.cluster_location]

  # CPU-only node pool (FinAI Studio runs no GPU/TPU workloads).
  node_pools = [{
    name         = "cpu-pool"
    machine_type = "n1-standard-4"
    autoscaling  = true
    min_count    = 1
    max_count    = 3
    disk_size_gb = 100
    disk_type    = "pd-standard"
  }]
}

provider "kubernetes" {
  alias                  = "app"
  host                   = local.host
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = local.ca_certificate
}

data "google_container_cluster" "default" {
  count    = var.create_cluster ? 0 : 1
  name     = var.cluster_name
  location = var.cluster_location
}

module "gke" {
  count   = var.create_cluster ? 1 : 0
  source  = "terraform-google-modules/kubernetes-engine/google"
  version = ">= 29.0"

  project_id             = var.project_id
  create_service_account = var.create_cluster_service_account
  service_account        = var.cluster_service_account

  name               = var.cluster_name
  region             = local.region
  regional           = local.is_regional
  zones              = local.zones
  kubernetes_version = var.kubernetes_version

  remove_default_node_pool = true
  initial_node_count       = 1

  network           = var.network_name
  subnetwork        = var.subnetwork_name
  ip_range_pods     = var.ip_range_pods
  ip_range_services = var.ip_range_services

  issue_client_certificate = true

  node_pools = local.node_pools

  node_pools_oauth_scopes = {
    all = ["https://www.googleapis.com/auth/cloud-platform"]
  }
}

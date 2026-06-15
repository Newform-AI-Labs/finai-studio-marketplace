# =============================================================================
# Inputs. Infra/cluster variables follow the Marketplace Terraform Kubernetes
# reference module; FinAI-specific values are appended (with defaults so
# `terraform plan` runs during validation).
# =============================================================================

variable "project_id" {
  type        = string
  description = "GCP project id"
}

# ── Marketplace ──────────────────────────────────────────────────────────────
variable "goog_cm_deployment_name" {
  type        = string
  description = "Marketplace deployment name (injected automatically). Used as the Helm release name."
  default     = ""
}

# ── Helm chart coordinates (overridden by mpdev to the republished chart) ────
variable "helm_release_name" {
  type    = string
  default = ""
}

variable "helm_chart_repo" {
  type    = string
  default = "oci://us-docker.pkg.dev/newform-public/finai-studio-repo"
}

variable "helm_chart_name" {
  type    = string
  default = "finai-studio"
}

variable "helm_chart_version" {
  type    = string
  default = "1.0"
}

variable "namespace" {
  type    = string
  default = "agentic-ai-internal"
}

# ── Cluster ──────────────────────────────────────────────────────────────────
variable "create_cluster" {
  type    = bool
  default = false
}

variable "create_cluster_service_account" {
  type    = bool
  default = false
}

variable "cluster_service_account" {
  type    = string
  default = ""
}

variable "kubernetes_version" {
  type    = string
  default = "1.30"
}

variable "cluster_name" {
  type = string
}

variable "cluster_location" {
  type = string
}

variable "ip_range_pods" {
  type    = string
  default = ""
}

variable "ip_range_services" {
  type    = string
  default = ""
}

variable "network_name" {
  type    = string
  default = "default"
}

variable "subnetwork_name" {
  type    = string
  default = "default"
}

variable "subnetwork_region" {
  type    = string
  default = "us-central1"
}

# ── Container images (overridden by mpdev to the republished Marketplace copies) ──
variable "backend_image_repo" {
  type    = string
  default = "us-docker.pkg.dev/newform-public/finai-studio-repo/finai-studio-backend"
}

variable "backend_image_tag" {
  type    = string
  default = "1.0"
}

variable "frontend_image_repo" {
  type    = string
  default = "us-docker.pkg.dev/newform-public/finai-studio-repo/finai-studio-frontend"
}

variable "frontend_image_tag" {
  type    = string
  default = "1.0"
}

# ── FinAI Studio customer environment (mapped onto chart values) ─────────────
variable "customer_region" {
  type    = string
  default = "us-central1"
}

variable "customer_artifact_registry" {
  type    = string
  default = ""
}

variable "build_context_bucket" {
  type    = string
  default = ""
}

variable "vertex_ai_location" {
  type    = string
  default = "us-central1"
}

variable "cloudsql_instance_connection_name" {
  type    = string
  default = ""
}

variable "database_existing_secret" {
  type    = string
  default = "finai-db-credentials"
}

variable "studio_controller_gsa" {
  type    = string
  default = ""
}

variable "image_builder_gsa" {
  type    = string
  default = ""
}

variable "agent_runtime_gsa" {
  type    = string
  default = ""
}

variable "workflow_runtime_gsa" {
  type    = string
  default = ""
}

variable "datasource_runtime_gsa" {
  type    = string
  default = ""
}

variable "preinstall_validator_gsa" {
  type    = string
  default = ""
}

variable "backend_replicas" {
  type    = number
  default = 2
}

variable "frontend_replicas" {
  type    = number
  default = 2
}

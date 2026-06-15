# =============================================================================
# Helm release — installs the FinAI Studio chart and maps install-form inputs
# onto chart values.
# =============================================================================

provider "helm" {
  alias = "app"
  kubernetes {
    host                   = local.host
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = local.ca_certificate
  }
}

locals {
  helm_release_name = var.helm_release_name != "" ? var.helm_release_name : "finai-studio-${random_string.suffix.result}"
  vertex_ai_project = var.project_id
}

resource "helm_release" "primary" {
  provider = helm.app

  name             = var.goog_cm_deployment_name != "" ? var.goog_cm_deployment_name : local.helm_release_name
  repository       = var.helm_chart_repo
  chart            = var.helm_chart_name
  version          = var.helm_chart_version
  namespace        = var.namespace
  create_namespace = true

  set {
    name  = "customer.projectId"
    value = var.project_id
  }
  set {
    name  = "customer.region"
    value = var.customer_region
  }
  set {
    name  = "customer.artifactRegistry"
    value = var.customer_artifact_registry
  }
  set {
    name  = "customer.buildContextBucket"
    value = var.build_context_bucket
  }
  set {
    name  = "vertexAi.location"
    value = var.vertex_ai_location
  }
  set {
    name  = "vertexAi.projectName"
    value = local.vertex_ai_project
  }
  set {
    name  = "namespaces.control"
    value = var.namespace
  }
  set {
    name  = "database.cloudSqlProxy.instanceConnectionName"
    value = var.cloudsql_instance_connection_name
  }
  set {
    name  = "database.existingSecret"
    value = var.database_existing_secret
  }
  set {
    name  = "serviceAccounts.studioControllerGsa"
    value = var.studio_controller_gsa
  }
  set {
    name  = "serviceAccounts.kanikoBuilderGsa"
    value = var.image_builder_gsa
  }
  set {
    name  = "serviceAccounts.agentRuntimeGsa"
    value = var.agent_runtime_gsa
  }
  set {
    name  = "serviceAccounts.workflowRuntimeGsa"
    value = var.workflow_runtime_gsa
  }
  set {
    name  = "serviceAccounts.datasourceRuntimeGsa"
    value = var.datasource_runtime_gsa
  }
  set {
    name  = "preinstallValidation.gsaEmail"
    value = var.preinstall_validator_gsa
  }
  set {
    name  = "backend.replicas"
    value = var.backend_replicas
  }
  set {
    name  = "frontend.replicas"
    value = var.frontend_replicas
  }
}

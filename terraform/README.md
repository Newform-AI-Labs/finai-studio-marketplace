# FinAI Studio — Marketplace Terraform deployer

Terraform module that Google Cloud Marketplace runs to install **FinAI Studio**
into a customer's existing GKE cluster. It uses the Helm provider to deploy the
published chart from Artifact Registry and maps the install-form inputs onto
chart values.

## What it deploys

- Helm release of `oci://us-docker.pkg.dev/newform-public/finai-studio-repo/finai-studio:1.0`
  into the control-plane namespace, which provisions the control plane
  (frontend + backend), agent / workflow / datasource runtimes, Workload
  Identity service accounts, RBAC, and the pre-install validation hook.

## Inputs

| Name | Description | Required |
|---|---|---|
| `goog_cm_deployment_name` | Deployment name (injected by Marketplace). | yes |
| `project_id` | Customer GCP project ID. | yes |
| `gke_cluster_name` | Existing GKE cluster name. | yes |
| `gke_cluster_location` | Cluster region/zone. | yes |
| `control_namespace` | Control-plane namespace (default `agentic-ai-internal`). | no |
| `customer_region` | Primary region (default `us-central1`). | no |
| `customer_artifact_registry` | Customer Artifact Registry path (host/project/repo). | yes |
| `build_context_bucket` | GCS bucket for Kaniko build context. | yes |
| `vertex_ai_location` | Vertex AI region (default `us-central1`). | no |
| `cloudsql_instance_connection_name` | Cloud SQL connection name (project:region:instance). | yes |
| `database_existing_secret` | K8s Secret with the DB password (default `finai-db-credentials`). | no |
| `studio_controller_gsa` / `image_builder_gsa` / `agent_runtime_gsa` | Workload Identity GSA emails. | yes |
| `workflow_runtime_gsa` / `datasource_runtime_gsa` / `preinstall_validator_gsa` | Additional GSA emails. | no |
| `backend_replicas` / `frontend_replicas` | Replica counts (default 2). | no |

## Outputs

| Name | Description |
|---|---|
| `deployment_name` | Helm release name. |
| `control_namespace` | Namespace where the control plane is installed. |
| `chart_version` | Installed chart version. |

## Prerequisites (customer-provisioned)

GKE cluster, VPC, Cloud SQL (Postgres + pgvector), Artifact Registry repo, a
build-context GCS bucket, the Workload Identity GSAs above, and any required
Secret Manager secrets. The chart's pre-install validation hook verifies these
and aborts on failure.

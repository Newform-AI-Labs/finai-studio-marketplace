output "deployment_name" {
  description = "Helm release name for this FinAI Studio deployment."
  value       = helm_release.primary.name
}

output "namespace" {
  description = "Namespace where the control plane is installed."
  value       = var.namespace
}

output "chart_version" {
  description = "Installed FinAI Studio chart version."
  value       = var.helm_chart_version
}

output "project_id" {
  description = "GCP project ID."
  value       = var.project_id
}

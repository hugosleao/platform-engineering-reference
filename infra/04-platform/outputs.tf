output "backstage_url" {
  description = "Backstage URL"
  value       = "https://backstage.${var.domain_name}"
}

output "backstage_image_uri" {
  description = "Backstage Custom Image URI"
  value       = "${aws_ecr_repository.backstage_git.repository_url}:latest"
}

output "argocd_url" {
  description = "ArgoCD URL"
  value       = "https://argocd.${var.domain_name}"
}

output "argocd_admin_password_command" {
  description = "Command to get ArgoCD admin password"
  value       = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}

output "postgres_host" {
  description = "PostgreSQL Host"
  value       = "postgresql.${kubernetes_namespace.backstage.metadata[0].name}.svc.cluster.local"
}

output "crossplane_namespace" {
  description = "Crossplane Namespace"
  value       = kubernetes_namespace.crossplane.metadata[0].name
}

output "kaniko_build_status" {
  description = "Kaniko Build Job Status"
  value       = "Image built: ${aws_ecr_repository.backstage_git.repository_url}:latest"
}

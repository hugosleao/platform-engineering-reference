output "nginx_ingress_loadbalancer_hostname" {
  description = "NGINX Ingress LoadBalancer Hostname"
  value       = try(data.kubernetes_service.nginx_ingress.status[0].load_balancer[0].ingress[0].hostname, "pending")
}

output "backstage_url" {
  description = "Backstage URL"
  value       = "https://backstage.${var.domain_name}"
}

output "argocd_url" {
  description = "ArgoCD URL"
  value       = "https://argocd.${var.domain_name}"
}

output "letsencrypt_issuer" {
  description = "Let's Encrypt ClusterIssuer"
  value       = "letsencrypt-prod"
}

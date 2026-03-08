# ==========================================
# ArgoCD
# ==========================================

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "7.7.11"
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  values = [
    yamlencode({
      global = {
        domain = "argocd.${var.domain_name}"
      }
      server = {
        ingress = {
          enabled = true
          ingressClassName = "nginx"
          annotations = {
            "cert-manager.io/cluster-issuer" = data.terraform_remote_state.networking.outputs.letsencrypt_issuer
          }
          hosts = ["argocd.${var.domain_name}"]
          tls = [{
            secretName = "argocd-tls"
            hosts      = ["argocd.${var.domain_name}"]
          }]
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace.argocd]
}

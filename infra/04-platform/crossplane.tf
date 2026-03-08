# ==========================================
# Crossplane
# ==========================================

resource "helm_release" "crossplane" {
  name       = "crossplane"
  repository = "https://charts.crossplane.io/stable"
  chart      = "crossplane"
  version    = "1.18.2"
  namespace  = kubernetes_namespace.crossplane.metadata[0].name

  set {
    name  = "args[0]"
    value = "--enable-composition-revisions"
  }

  depends_on = [kubernetes_namespace.crossplane]
}

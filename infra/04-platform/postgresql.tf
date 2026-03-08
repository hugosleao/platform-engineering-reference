# ==========================================
# PostgreSQL In-Cluster
# ==========================================

resource "random_password" "postgres" {
  length  = 16
  special = false
}

resource "kubernetes_secret" "postgres" {
  metadata {
    name      = "postgres-credentials"
    namespace = kubernetes_namespace.backstage.metadata[0].name
  }

  data = {
    POSTGRES_USER     = "backstage"
    POSTGRES_PASSWORD = random_password.postgres.result
    POSTGRES_DB       = "backstage"
  }
}

# Espera explícita pelo EBS CSI ficar pronto antes do PostgreSQL
resource "null_resource" "wait_ebs_csi_ready" {
  provisioner "local-exec" {
    command = "kubectl rollout status daemonset ebs-csi-node -n kube-system --timeout=300s"
  }
}

resource "helm_release" "postgresql" {
  name       = "postgresql"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "postgresql"
  version    = "15.5.38"
  namespace  = kubernetes_namespace.backstage.metadata[0].name

  set {
    name  = "auth.username"
    value = "backstage"
  }

  set_sensitive {
    name  = "auth.password"
    value = random_password.postgres.result
  }

  set {
    name  = "auth.database"
    value = "backstage"
  }

  set {
    name  = "primary.persistence.enabled"
    value = "true"
  }

  set {
    name  = "primary.persistence.size"
    value = "10Gi"
  }

  set {
    name  = "primary.persistence.storageClass"
    value = "gp2"
  }

  timeout = 600

  depends_on = [
    kubernetes_namespace.backstage,
    null_resource.wait_ebs_csi_ready
  ]
}

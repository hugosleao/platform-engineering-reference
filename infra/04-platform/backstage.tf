# ==========================================
# Backstage
# ==========================================

# GitHub credentials from AWS Secrets Manager
data "aws_secretsmanager_secret_version" "github" {
  secret_id = var.github_secrets_manager_secret_id
}

locals {
  github_secrets = jsondecode(data.aws_secretsmanager_secret_version.github.secret_string)
}

# GitHub Secrets
resource "kubernetes_secret" "backstage_github" {
  metadata {
    name      = "backstage-github"
    namespace = kubernetes_namespace.backstage.metadata[0].name
  }

  data = {
    # GitHub App — mesmo app para catálogo, scaffolder e login
    # Sem PAT pessoal em nenhum ponto da stack
    GITHUB_APP_ID          = lookup(local.github_secrets, "GITHUB_APP_ID", "")
    GITHUB_CLIENT_ID       = lookup(local.github_secrets, "GITHUB_CLIENT_ID", "")
    GITHUB_CLIENT_SECRET   = lookup(local.github_secrets, "GITHUB_CLIENT_SECRET", "")
    GITHUB_WEBHOOK_SECRET  = lookup(local.github_secrets, "GITHUB_WEBHOOK_SECRET", "")
    GITHUB_APP_PRIVATE_KEY = lookup(local.github_secrets, "GITHUB_APP_PRIVATE_KEY", "")
  }
}

# Backstage Helm Chart
resource "helm_release" "backstage" {
  name       = "backstage"
  repository = "https://backstage.github.io/charts"
  chart      = "backstage"
  version    = "2.0.0"
  namespace  = kubernetes_namespace.backstage.metadata[0].name

  values = [
    yamlencode({
      backstage = {
        image = {
          registry   = split("/", aws_ecr_repository.backstage_git.repository_url)[0]
          repository = "backstage-git"
          tag        = "latest"
        }
        extraEnvVars = [
          {
            name  = "POSTGRES_HOST"
            value = "postgresql.${kubernetes_namespace.backstage.metadata[0].name}.svc.cluster.local"
          },
          {
            name  = "POSTGRES_PORT"
            value = "5432"
          },
          {
            name = "POSTGRES_USER"
            valueFrom = {
              secretKeyRef = {
                name = kubernetes_secret.postgres.metadata[0].name
                key  = "POSTGRES_USER"
              }
            }
          },
          {
            name = "POSTGRES_PASSWORD"
            valueFrom = {
              secretKeyRef = {
                name = kubernetes_secret.postgres.metadata[0].name
                key  = "POSTGRES_PASSWORD"
              }
            }
          },
          {
            name = "GITHUB_APP_ID"
            valueFrom = {
              secretKeyRef = {
                name = kubernetes_secret.backstage_github.metadata[0].name
                key  = "GITHUB_APP_ID"
              }
            }
          },
          {
            name = "GITHUB_CLIENT_ID"
            valueFrom = {
              secretKeyRef = {
                name = kubernetes_secret.backstage_github.metadata[0].name
                key  = "GITHUB_CLIENT_ID"
              }
            }
          },
          {
            name = "GITHUB_CLIENT_SECRET"
            valueFrom = {
              secretKeyRef = {
                name = kubernetes_secret.backstage_github.metadata[0].name
                key  = "GITHUB_CLIENT_SECRET"
              }
            }
          },
          {
            name = "GITHUB_WEBHOOK_SECRET"
            valueFrom = {
              secretKeyRef = {
                name = kubernetes_secret.backstage_github.metadata[0].name
                key  = "GITHUB_WEBHOOK_SECRET"
              }
            }
          },
          {
            name = "GITHUB_APP_PRIVATE_KEY"
            valueFrom = {
              secretKeyRef = {
                name = kubernetes_secret.backstage_github.metadata[0].name
                key  = "GITHUB_APP_PRIVATE_KEY"
              }
            }
          }
        ]
      }
      ingress = {
        enabled   = true
        className = "nginx"
        annotations = {
          "cert-manager.io/cluster-issuer" = data.terraform_remote_state.networking.outputs.letsencrypt_issuer
        }
        host = "backstage.${var.domain_name}"
        tls = {
          enabled    = true
          secretName = "backstage-tls"
        }
      }
    })
  ]

  depends_on = [
    kubernetes_namespace.backstage,
    helm_release.postgresql,
    kubernetes_secret.backstage_github,
    kubernetes_job_v1.build_backstage_image
  ]
}

# ==========================================
# Backstage Custom Image Build (Kaniko + ECR)
# ==========================================

# ECR Repository
resource "aws_ecr_repository" "backstage_git" {
  name                 = "backstage-git"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = false
  }

  tags = {
    Name = "backstage-git"
  }
}

# IAM Role para Kaniko (Pod Identity)
data "aws_caller_identity" "current" {}

resource "aws_iam_role" "kaniko_ecr" {
  name = "kaniko-ecr-push"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "pods.eks.amazonaws.com"
      }
      Action = [
        "sts:AssumeRole",
        "sts:TagSession"
      ]
    }]
  })
}

resource "aws_iam_policy" "kaniko_ecr_policy" {
  name        = "kaniko-ecr-push-policy"
  description = "Permite Kaniko push para ECR"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = aws_ecr_repository.backstage_git.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "kaniko_ecr_attach" {
  role       = aws_iam_role.kaniko_ecr.name
  policy_arn = aws_iam_policy.kaniko_ecr_policy.arn
}

# EKS Pod Identity Association
resource "aws_eks_pod_identity_association" "kaniko" {
  cluster_name    = data.terraform_remote_state.eks.outputs.cluster_name
  namespace       = kubernetes_namespace.backstage.metadata[0].name
  service_account = "kaniko-builder"
  role_arn        = aws_iam_role.kaniko_ecr.arn

  depends_on = [kubernetes_namespace.backstage]
}

# Kubernetes ServiceAccount
resource "kubernetes_service_account" "kaniko" {
  metadata {
    name      = "kaniko-builder"
    namespace = kubernetes_namespace.backstage.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.kaniko_ecr.arn
    }
  }

  depends_on = [kubernetes_namespace.backstage]
}

# Kaniko Docker Config (credHelpers) - FIX 401
resource "kubernetes_secret" "kaniko_docker_config" {
  metadata {
    name      = "kaniko-docker-config"
    namespace = kubernetes_namespace.backstage.metadata[0].name
  }

  data = {
    "config.json" = jsonencode({
      credHelpers = {
        "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com" = "ecr-login"
      }
    })
  }

  depends_on = [kubernetes_namespace.backstage]
}

# ConfigMap com Dockerfile
resource "kubernetes_config_map" "dockerfile_backstage" {
  metadata {
    name      = "dockerfile-backstage"
    namespace = kubernetes_namespace.backstage.metadata[0].name
  }

  data = {
    Dockerfile = <<-EOF
      FROM ghcr.io/backstage/backstage:latest
      USER root
      RUN apt-get update && \
          apt-get install -y git ca-certificates && \
          rm -rf /var/lib/apt/lists/*
      RUN git config --global user.name "Backstage Platform" && \
          git config --global user.email "platform@devopstia.com" && \
          git config --global init.defaultBranch master
      USER node
      WORKDIR /app
    EOF
  }

  depends_on = [kubernetes_namespace.backstage]
}

# Kaniko Build Job
resource "kubernetes_job_v1" "build_backstage_image" {
  metadata {
    name      = "build-backstage-git"
    namespace = kubernetes_namespace.backstage.metadata[0].name
  }

  spec {
    ttl_seconds_after_finished = 600
    backoff_limit              = 2

    template {
      metadata {
        labels = {
          app = "kaniko-build"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.kaniko.metadata[0].name
        restart_policy       = "Never"

        container {
          name  = "kaniko"
          image = "gcr.io/kaniko-project/executor:v1.23.0"

          args = [
            "--dockerfile=/workspace/Dockerfile",
            "--context=dir:///workspace",
            "--destination=${aws_ecr_repository.backstage_git.repository_url}:latest",
            "--cache=true",
            "--cache-ttl=24h",
            "--verbosity=info"
          ]

          env {
            name  = "AWS_REGION"
            value = var.aws_region
          }

          env {
            name  = "AWS_STS_REGIONAL_ENDPOINTS"
            value = "regional"
          }

          resources {
            requests = {
              memory = "1Gi"
              cpu    = "500m"
            }
            limits = {
              memory = "2Gi"
              cpu    = "1000m"
            }
          }

          volume_mount {
            name       = "dockerfile"
            mount_path = "/workspace"
          }

          volume_mount {
            name       = "docker-config"
            mount_path = "/kaniko/.docker"
            read_only  = true
          }
        }

        volume {
          name = "dockerfile"
          config_map {
            name = kubernetes_config_map.dockerfile_backstage.metadata[0].name
          }
        }

        volume {
          name = "docker-config"
          secret {
            secret_name = kubernetes_secret.kaniko_docker_config.metadata[0].name
            items {
              key  = "config.json"
              path = "config.json"
            }
          }
        }
      }
    }
  }

  wait_for_completion = true
  timeouts {
    create = "10m"
  }

  depends_on = [
    kubernetes_namespace.backstage,
    kubernetes_service_account.kaniko,
    kubernetes_secret.kaniko_docker_config,
    kubernetes_config_map.dockerfile_backstage,
    aws_eks_pod_identity_association.kaniko,
    aws_ecr_repository.backstage_git
  ]
}

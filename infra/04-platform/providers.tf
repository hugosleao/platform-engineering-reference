# ==========================================
# Terraform + Providers Configuration
# ==========================================

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
  
  backend "s3" {
    bucket         = "PLACEHOLDER_TF_STATE_BUCKET"
    key            = "golden-triangle/platform/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "PLACEHOLDER_TF_LOCK_TABLE"
    encrypt        = true
  }
}

# ==========================================
# Data Sources
# ==========================================

data "terraform_remote_state" "eks" {
  backend = "s3"
  
  config = {
    bucket = "PLACEHOLDER_TF_STATE_BUCKET"
    key    = "golden-triangle/eks/terraform.tfstate"
    region = "us-east-1"
  }
}

data "terraform_remote_state" "networking" {
  backend = "s3"
  
  config = {
    bucket = "PLACEHOLDER_TF_STATE_BUCKET"
    key    = "golden-triangle/networking/terraform.tfstate"
    region = "us-east-1"
  }
}

data "aws_eks_cluster" "cluster" {
  name = data.terraform_remote_state.eks.outputs.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = data.terraform_remote_state.eks.outputs.cluster_name
}

# ==========================================
# Providers
# ==========================================

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = var.owner
    }
  }
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

# ==========================================
# Namespaces
# ==========================================

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

resource "kubernetes_namespace" "backstage" {
  metadata {
    name = "backstage"
  }
}

resource "kubernetes_namespace" "crossplane" {
  metadata {
    name = "crossplane-system"
  }
}


# ==========================================
# Módulo 02: EKS Cluster Simplificado
# ==========================================

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  backend "s3" {
    bucket         = "PLACEHOLDER_TF_STATE_BUCKET"
    key            = "golden-triangle/eks/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "PLACEHOLDER_TF_LOCK_TABLE"
    encrypt        = true
  }
}

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

# ==========================================
# Data Sources (VPC outputs)
# ==========================================

data "terraform_remote_state" "vpc" {
  backend = "s3"
  
  config = {
    bucket = "PLACEHOLDER_TF_STATE_BUCKET"
    key    = "golden-triangle/vpc/terraform.tfstate"
    region = "us-east-1"
  }
}

# ==========================================
# EKS Module (Simplificado)
# ==========================================

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  # Acesso público (lab)
  cluster_endpoint_public_access = true

  # VPC
  vpc_id     = data.terraform_remote_state.vpc.outputs.vpc_id
  subnet_ids = data.terraform_remote_state.vpc.outputs.public_subnet_ids

  # Addons mínimos
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    eks-pod-identity-agent = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }

  # Node Group SPOT (custo baixo)
  eks_managed_node_groups = {
    default = {
      name = "default-ng"

      instance_types = ["t3.medium"]
      capacity_type  = "SPOT"

      min_size     = 2
      max_size     = 4
      desired_size = 2

      labels = {
        role = "worker"
      }

      tags = {
        Name = "${var.cluster_name}-worker"
      }
    }
  }

  # Access Entry (substitui aws-auth ConfigMap)
  enable_cluster_creator_admin_permissions = true

  tags = {
    Name = var.cluster_name
  }
}

# ==========================================
# Permissão EBS CSI no Node Group (lab)
# ==========================================

resource "aws_iam_role_policy_attachment" "ebs_csi_node_policy" {
  role       = module.eks.eks_managed_node_groups["default"].iam_role_name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

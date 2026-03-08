terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "golden-triangle-lab"
      Environment = "mgmt"
      ManagedBy   = "terraform"
      Owner       = "hugosleao"
    }
  }
}

# ==========================================
# S3 Bucket for Terraform State
# ==========================================
resource "aws_s3_bucket" "terraform_state" {
  bucket = "hugosleao-terraform-state-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "Terraform State Bucket"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ==========================================
# DynamoDB Table for State Locking
# ==========================================
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "hugosleao-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name = "Terraform State Lock Table"
  }
}

# ==========================================
# S3 Bucket for Lab Backups (Backstage/ArgoCD)
# ==========================================
resource "aws_s3_bucket" "lab_backup" {
  bucket = "hugosleao-lab-backup-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "Lab Backup Bucket"
  }
}

resource "aws_s3_bucket_versioning" "lab_backup" {
  bucket = aws_s3_bucket.lab_backup.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "lab_backup" {
  bucket = aws_s3_bucket.lab_backup.id

  rule {
    id     = "delete-old-backups"
    status = "Enabled"

    filter {}  # Aplicar a todos objetos

    expiration {
      days = 30
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}

# ==========================================
# Data Sources
# ==========================================
data "aws_caller_identity" "current" {}

# ==========================================
# Outputs
# ==========================================
output "terraform_state_bucket" {
  value       = aws_s3_bucket.terraform_state.id
  description = "S3 bucket para Terraform state"
}

output "terraform_locks_table" {
  value       = aws_dynamodb_table.terraform_locks.id
  description = "DynamoDB table para Terraform locks"
}

output "lab_backup_bucket" {
  value       = aws_s3_bucket.lab_backup.id
  description = "S3 bucket para backups do lab"
}

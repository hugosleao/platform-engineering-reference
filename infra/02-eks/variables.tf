variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "EKS Cluster Name"
  type        = string
  default     = "eks-lab"
}

variable "cluster_version" {
  description = "EKS Cluster Version"
  type        = string
  default     = "1.31"
}

variable "project_name" {
  description = "Project Name"
  type        = string
  default     = "golden-triangle-lab"
}

variable "environment" {
  description = "Environment"
  type        = string
  default     = "lab"
}

variable "owner" {
  description = "Owner"
  type        = string
  default     = "hugosleao"
}

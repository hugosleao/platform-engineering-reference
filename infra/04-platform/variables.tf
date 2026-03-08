variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
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

variable "domain_name" {
  description = "Domain Name"
  type        = string
  default     = "devopstia.com"
}

variable "github_secrets_manager_secret_id" {
  description = "AWS Secrets Manager secret name or ARN containing GitHub credentials JSON"
  type        = string
}

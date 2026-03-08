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
  description = "Domain Name (Route53 Hosted Zone)"
  type        = string
  default     = "devopstia.com"
}

variable "letsencrypt_email" {
  description = "Email for Let's Encrypt certificates"
  type        = string
  default     = "hugosleao@example.com"
}

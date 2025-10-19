variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "secrets-manager-poc"
}

# Sensitive variables
variable "api_key" {
  description = "API key for external service"
  type        = string
  sensitive   = true
}

variable "api_key_secret" {
  description = "API key secret for external service"
  type        = string
  sensitive   = true
}

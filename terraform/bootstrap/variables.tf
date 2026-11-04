variable "project" {
  type        = string
  description = "The name of the project."
  default     = "devops-platform"
}

variable "environment" {
  type        = string
  description = "The environment name (e.g., dev, staging, prod)."
  default     = "bootstrap"
}

variable "aws_region" {
  type        = string
  description = "The AWS region to deploy resources in."
  default     = "us-east-1"
}

variable "noncurrent_version_expiration_days" {
  type        = number
  description = "The number of days after which noncurrent versions of objects in the S3 bucket will be deleted."
  default     = 90
}
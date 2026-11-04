terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # This tells Terraform: "Use S3 for state, but get my settings from a config file later"
  backend "s3" {}
}
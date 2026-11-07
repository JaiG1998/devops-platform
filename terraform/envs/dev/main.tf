provider "aws" {
  region = "us-east-1"
}

# Fetch caller identity to populate admin_role_arns automatically
data "aws_caller_identity" "current" {}

locals {
  cluster_name = "dev-eks-cluster"
  environment  = "dev"

  tags = {
    Environment = local.environment
    ManagedBy   = "Terraform"
    Project     = "LearningVPC-EKS"
  }
}

# --- Module 1: Network Foundation (VPC) ---
module "vpc_dev" {
  source = "../../modules/vpc"

  name               = "dev-network"
  vpc_cidr           = "10.10.0.0/16"
  az_count           = 2
  single_nat_gateway = true
  cluster_name       = local.cluster_name

  tags = local.tags
}

# --- Module 2: Container Platform (EKS) ---
module "eks_dev" {
  source = "../../modules/eks"

  cluster_name       = local.cluster_name
  kubernetes_version = "1.35"

  # Pass output attributes directly from the VPC module
  vpc_id             = module.vpc_dev.vpc_id
  private_subnet_ids = module.vpc_dev.private_subnet_ids

  # Security & Access Control
  endpoint_public_access = true
  public_access_cidrs    = ["0.0.0.0/0"] # Update with your specific IP (/32) for strict access
  admin_role_arns        = [data.aws_caller_identity.current.arn]

  # Cost-Optimized Managed Node Group Configuration
  node_capacity_type  = "SPOT"
  node_instance_types = ["t3.medium", "t3a.medium"]
  node_min_size       = 1
  node_desired_size   = 2
  node_max_size       = 3
  node_disk_size      = 20

  # Control Plane Logging
  enabled_log_types  = ["api", "audit", "authenticator"]
  log_retention_days = 7

  tags = local.tags
}

provider "aws" {
  region = "us-east-1"
}

module "vpc_dev" {
  source = "../../modules/vpc"

  name               = "dev-cluster"
  vpc_cidr           = "10.10.0.0/16"
  az_count           = 2
  single_nat_gateway = true
  cluster_name       = "dev-eks-cluster"

  tags = {
    Environment = "dev"
    ManagedBy   = "Terraform"
    Project     = "devops-platform"
  }
}

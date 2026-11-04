provider "aws" {
  region = "us-east-1"
}

module "dev_app" {
  source       = "../../modules/app_workload"
  environment  = "dev"
  instance_type = "t3.nano"  # Smaller instance for dev
  project = "devops-platform"
  ami_id       = "ami-0c230065b91270bc6"
}

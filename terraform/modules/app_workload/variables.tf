variable "project" {
  type        = string
  description = "The name of the project."
  default     = "devops_platform"
}

variable "environment" {
  type        = string
  description = "The environment name (e.g., dev, staging, prod)."
  default     = "dev"
}

variable "ami_id" {
  type        = string
  description = "The ID of the AMI to use for the EC2 instance."
  default     = "ami-0c55b159cbfafe1f0" # Example AMI ID, replace with a valid one for your region
}

variable "instance_type" {
  type        = string
  description = "The type of EC2 instance to launch."
  default     = "t2.micro"
}
variable "name" {
  type        = string
  description = "Name prefix used for all resources and tags (e.g., dev-vpc)"
}

variable "vpc_cidr" {
  description = "The IPv4 CIDR block for the VPC"
  type        = string
  default     = "10.10.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "The vpc_cidr must be a valid IPv4 CIDR block in standard format (e.g., 10.10.0.0/16)."
  }
}

variable "az_count" {
  description = "Number of Availability Zones to deploy subnets across"
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2
    error_message = "The az_count must be at least 2 to support multi-AZ subnets and high availability."
  }
}

variable "single_nat_gateway" {
  description = "If true, creates a single shared NAT Gateway for all private subnets (cheaper for dev). If false, creates one NAT per AZ."
  type        = bool
  default     = true
}

variable "cluster_name" {
  description = "Name of the EKS cluster. Used for required AWS VPC CNI and load balancer subnet tags."
  type        = string
  default     = ""
}

variable "tags" {
  description = "A map of standard tags to apply to all provisioned resources"
  type        = map(string)
  default     = {}
}
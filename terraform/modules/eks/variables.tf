# --- Cluster Identity & Versioning ---

variable "cluster_name" {
  description = "Name of the EKS cluster. Used in resource names, IAM roles, and tags."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9-_]{1,99}$", var.cluster_name))
    error_message = "cluster_name must start with an alphanumeric character and contain only alphanumeric, hyphen, or underscore characters (2-100 characters)."
  }
}

variable "kubernetes_version" {
  description = "Kubernetes version to deploy. Keep within standard AWS EKS support to avoid extended support charges."
  type        = string
  default     = "1.35"

  validation {
    condition     = can(regex("^1\\.(2[8-9]|[3-9][0-9])$", var.kubernetes_version))
    error_message = "kubernetes_version must be a valid major.minor string (e.g., '1.35')."
  }
}

# --- Network Integrations ---

# tflint-ignore: terraform_unused_declarations
variable "vpc_id" {
  description = "ID of the VPC where the cluster and node security groups will be created."
  type        = string

  validation {
    condition     = can(regex("^vpc-[a-f0-9]+$", var.vpc_id))
    error_message = "vpc_id must be a valid AWS VPC identifier starting with 'vpc-'."
  }
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs where EKS worker nodes and pods will be provisioned."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "private_subnet_ids must contain at least 2 subnet IDs for multi-AZ high availability."
  }
}

# --- Control Plane API Access ---

variable "endpoint_public_access" {
  description = "Whether the Amazon EKS public API server endpoint is enabled."
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "List of CIDR blocks that can access the EKS public API server endpoint. Defaults to restricted access."
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = length(var.public_access_cidrs) > 0
    error_message = "public_access_cidrs cannot be an empty list when endpoint_public_access is enabled."
  }
}

# --- Managed Node Group Inputs ---

variable "node_instance_types" {
  description = "List of EC2 instance types for the node group. Ordered by preference for Spot allocation."
  type        = list(string)
  default     = ["t3.medium", "t3a.medium"]

  validation {
    condition     = length(var.node_instance_types) > 0
    error_message = "At least one EC2 instance type must be specified."
  }
}

variable "node_capacity_type" {
  description = "Capacity type for the managed node group (SPOT or ON_DEMAND). SPOT saves up to 70% for dev workloads."
  type        = string
  default     = "SPOT"

  validation {
    condition     = contains(["SPOT", "ON_DEMAND"], var.node_capacity_type)
    error_message = "node_capacity_type must be either 'SPOT' or 'ON_DEMAND'."
  }
}

variable "node_min_size" {
  description = "Minimum number of worker nodes the group can scale down to."
  type        = number
  default     = 1

  validation {
    condition     = var.node_min_size >= 1
    error_message = "node_min_size must be at least 1."
  }
}

variable "node_max_size" {
  description = "Maximum number of worker nodes the group can scale up to."
  type        = number
  default     = 3

  validation {
    condition     = var.node_max_size >= 1
    error_message = "node_max_size must be at least 1."
  }
}

variable "node_desired_size" {
  description = "Initial desired number of worker nodes."
  type        = number
  default     = 2
}

variable "node_disk_size" {
  description = "EBS root volume size in GB for worker nodes."
  type        = number
  default     = 20

  validation {
    condition     = var.node_disk_size >= 10 && var.node_disk_size <= 100
    error_message = "node_disk_size must be between 10 GB and 100 GB."
  }
}

# --- Security & Authentication ---

variable "admin_role_arns" {
  description = "List of IAM Role or User ARNs granted cluster-admin access entries in Kubernetes."
  type        = list(string)
  default     = []
}

# --- Logging & Compliance ---

variable "enabled_log_types" {
  description = "List of control plane log types to send to CloudWatch (api, audit, authenticator, controllerManager, scheduler)."
  type        = list(string)
  default     = ["api", "audit", "authenticator"]
}

variable "log_retention_days" {
  description = "Retention period in days for CloudWatch log groups to keep costs low."
  type        = number
  default     = 7

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365], var.log_retention_days)
    error_message = "log_retention_days must be a valid CloudWatch retention period."
  }
}

# --- Metadata Tagging ---

variable "tags" {
  description = "A map of tags to apply to all resources created by this module."
  type        = map(string)
  default     = {}
}
# --- 1. CloudWatch Log Group for Control Plane Logs ---
resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.log_retention_days

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-cloudwatch-log-group"
    }
  )
}

# --- 2. Amazon EKS Cluster Resource ---
resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  version  = var.kubernetes_version
  role_arn = aws_iam_role.cluster.arn

  # Enable control plane logging explicitly
  enabled_cluster_log_types = var.enabled_log_types

  # VPC and Subnet Configuration (Deployed entirely in private subnets)
  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_public_access  = var.endpoint_public_access
    endpoint_private_access = true
    public_access_cidrs     = var.endpoint_public_access ? var.public_access_cidrs : null
  }

  # Modern EKS Access Entry Authentication Configuration
  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  # Optional Secrets Encryption Config (Omitted by default for cost/complexity optimization in dev, 
  # but structured here if a KMS key ARN is provided)
  # dynamic "encryption_config" {
  #   for_each = var.kms_key_arn != "" ? [1] : []
  #   content {
  #     provider {
  #       key_arn = var.kms_key_arn
  #     }
  #     resources = ["secrets"]
  #   }
  # }

  # Explicit dependency ordering to ensure IAM permissions and CloudWatch logs exist first
  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_cloudwatch_log_group.cluster
  ]

  tags = merge(
    var.tags,
    {
      Name = var.cluster_name
    }
  )
}

# --- 3. EKS Access Entries & Cluster-Admin Policy Associations ---
resource "aws_eks_access_entry" "admin" {
  for_each = toset(var.admin_role_arns)

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value
  type          = "STANDARD"

  tags = var.tags
}

resource "aws_eks_access_policy_association" "admin_policy" {
  for_each = toset(var.admin_role_arns)

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = aws_eks_access_entry.admin[each.value].principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}
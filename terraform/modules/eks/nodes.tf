# --- Managed Node Group Resource ---
resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-spot-node-group"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.private_subnet_ids

  # Cost Optimization: Use SPOT capacity types with multi-instance diversity
  capacity_type  = var.node_capacity_type
  instance_types = var.node_instance_types # e.g., ["t3.medium", "t3a.medium", "t2.medium"]

  scaling_config {
    min_size     = var.node_min_size     # Default: 1 or 2
    desired_size = var.node_desired_size # Default: 2
    max_size     = var.node_max_size     # Default: 3
  }

  disk_size = var.node_disk_size

  # Rolling update configuration allowing 1 unavailable node during updates to maintain uptime
  update_config {
    max_unavailable = 1
  }

  # Node labels for workload scheduling and organization
  labels = {
    "Environment"   = "dev"
    "CapacityType"  = lower(var.node_capacity_type)
    "WorkloadType"  = "general"
  }

  # Explicit depends_on to ensure IAM role attachments are fully active before node launch
  depends_on = [
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly,
    aws_eks_access_policy_association.admin_policy
  ]

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-node-group"
    }
  )
}
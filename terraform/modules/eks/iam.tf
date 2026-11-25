# --- 1. EKS Cluster IAM Role & Policy Attachments ---
# Cluster Role Trust Relationship (eks.amazonaws.com):
# Allows the EKS service itself to assume this role so it can provision
# network interfaces, security groups, and communicate with worker nodes.

data "aws_iam_policy_document" "cluster_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${var.cluster_name}-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.cluster_assume_role.json

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-cluster-role"
    }
  )
}

# Attach the standard AWS-managed policy required for EKS clusters to manage resources
resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}


# --- 2. EKS Worker Node IAM Role & Policy Attachments ---

# Allows your EC2 worker instances to assume this role upon boot.

data "aws_iam_policy_document" "node_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  name               = "${var.cluster_name}-node-role"
  assume_role_policy = data.aws_iam_policy_document.node_assume_role.json

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-node-role"
    }
  )
}

# Standard managed worker node policy (joins cluster, manages EC2 instances)
resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node.name
}

# CNI policy required for the Amazon VPC CNI plugin to manage container IP addresses
resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy" # Note: standard AWS ARN for VPC CNI is AmazonEKS_CNI_Policy
  role       = aws_iam_role.node.name
}

# Read-only access to Amazon Elastic Container Registry (ECR) for pulling container images
resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node.name
}


# --- 3. EKS Access Entries & Cluster-Admin Policy Associations ---

resource "aws_eks_access_entry" "admin" {
  for_each = toset(var.admin_role_arns)

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value
  type          = "STANDARD"

  tags = var.tags
}

resource "aws_eks_access_entry" "viewer" {
  for_each = toset(var.viewer_role_arns)

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value
  type          = "STANDARD"

  tags = var.tags
}

resource "aws_eks_access_entry" "developer" {
  for_each = toset(var.developer_role_arns)

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value
  type          = "STANDARD"

  tags = var.tags
}

# Access policy associations: map access entries to Kubernetes groups via managed policies
resource "aws_eks_access_policy_association" "admin_policy" {
  for_each = toset(var.admin_role_arns)

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = aws_eks_access_entry.admin[each.value].principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

resource "aws_eks_access_policy_association" "viewer_policy" {
  for_each = toset(var.viewer_role_arns)

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = aws_eks_access_entry.viewer[each.value].principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"

  access_scope {
    type = "namespace"
  }
}

resource "aws_eks_access_policy_association" "developer_policy" {
  for_each = toset(var.developer_role_arns)

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = aws_eks_access_entry.developer[each.value].principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"

  access_scope {
    type = "namespace"
  }
}
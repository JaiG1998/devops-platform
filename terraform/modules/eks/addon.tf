# --- 1. EKS Core Add-ons ---

# VPC CNI Add-on (Manages pod IP allocation and network interfaces)
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = var.tags
}

# CoreDNS Add-on (Cluster internal DNS resolution)
resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "coredns"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  # Ensure VPC CNI is up first so CoreDNS pods can be assigned cluster IPs
  depends_on = [aws_eks_addon.vpc_cni]

  tags = var.tags
}

# Kube-Proxy Add-on (Maintains network rules on nodes for cluster communication)
resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "kube-proxy"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = var.tags
}


# --- 2. IAM OIDC Provider for IRSA (IAM Roles for Service Accounts) ---

# Extract the OIDC issuer host from the EKS cluster attribute (stripping the leading 'https://')
locals {
  oidc_issuer_url = replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")
}

# Fetch the TLS certificate from the cluster's OIDC issuer to compute the root CA thumbprint automatically
data "tls_certificate" "cluster" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

# Create the IAM OpenID Connect Provider
resource "aws_iam_openid_connect_provider" "oidc" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer # Updated from .openid[0].issuer

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-oidc-provider"
    }
  )
}
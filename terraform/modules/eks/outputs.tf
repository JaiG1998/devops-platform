# --- Cluster Identification & Endpoints ---

output "cluster_name" {
  description = "The name of the Amazon EKS cluster."
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "The endpoint URL for the EKS Kubernetes API server."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_version" {
  description = "The active Kubernetes version running on the EKS cluster."
  value       = aws_eks_cluster.this.version
}

output "cluster_certificate_authority_data" {
  description = "The Base64 encoded certificate authority data required for cluster authentication."
  value       = aws_eks_cluster.this.certificate_authority[0].data
  sensitive   = true # Marked sensitive to prevent plaintext exposure in terminal logs or state files
}

# --- Security & Networking References ---

output "cluster_security_group_id" {
  description = "The security group ID created and managed by EKS for the cluster control plane."
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "node_role_arn" {
  description = "The IAM Role ARN used by the worker node group."
  value       = aws_iam_role.node.arn
}

# --- IRSA (IAM Roles for Service Accounts) Outputs ---

output "oidc_provider_arn" {
  description = "The ARN of the IAM OIDC Provider created for the cluster, required for setting up IRSA trust policies."
  value       = aws_iam_openid_connect_provider.oidc.arn
}

output "oidc_issuer_url" {
  description = "The OIDC issuer URL associated with the EKS cluster."
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

# --- Developer Convenience Utility ---

output "kubeconfig_command" {
  description = "AWS CLI command to update your local kubeconfig file and connect to the new cluster."
  value       = "aws eks update-kubeconfig --name ${aws_eks_cluster.this.name} --region ${data.aws_region.current.name}"
}
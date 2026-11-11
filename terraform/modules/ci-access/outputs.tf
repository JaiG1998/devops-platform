output "role_arn" {
  value       = aws_iam_role.gha_plan.arn
  description = "The ARN of the GitHub Actions OIDC plan role"
}
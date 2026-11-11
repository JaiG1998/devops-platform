data "aws_iam_policy_document" "github_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_org}/${var.github_repo}:pull_request",
        "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/main",
        "repo:${var.github_org}@*/${var.github_repo}@*:pull_request",
        "repo:${var.github_org}@*/${var.github_repo}@*:ref:refs/heads/main"
      ]
    }
  }
}

data "aws_caller_identity" "current" {}

# OIDC Identity Provider (singleton per account/issuer URL)
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# IAM Plan Role
resource "aws_iam_role" "gha_plan" {
  name                 = "GitHubActionsTerraformPlanRole"
  assume_role_policy   = data.aws_iam_policy_document.github_assume_role.json
  max_session_duration = 3600
  description          = "IAM role assumed by GitHub Actions for secure Terraform planning via OIDC"

  tags = {
    Environment = "CI"
    ManagedBy   = "Terraform"
  }
}

# Attach Policies (e.g., Read-only access + backend state access)
resource "aws_iam_role_policy_attachment" "admin-access" {
  role       = aws_iam_role.gha_plan.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
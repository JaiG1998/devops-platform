data "aws_caller_identity" "current" {}

# S3 Bucket with unique naming convention: <project>-tfstate-<account-id>-bucket  
resource "aws_s3_bucket" "state" {
  bucket        = "${var.project}-tfstate-${data.aws_caller_identity.current.account_id}-${var.environment}-bucket"
  force_destroy = false

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "${var.project}-tfstate-${data.aws_caller_identity.current.account_id}-${var.environment}-bucket"
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# 1. Enable versioning for the S3 bucket to keep track of changes to the state file.
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id


  versioning_configuration {
    status = "Enabled"
  }
}

# 2. Server-side encryption for the S3 bucket to ensure that the state file is encrypted at rest.
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# 3. Block all public access to the S3 bucket to prevent unauthorized access to the state file.
resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 4. Bucket Policy Denying Insecure (Non-TLS/HTTP) Requests to the S3 Bucket
resource "aws_s3_bucket_policy" "deny_non_tls_requests" {
  bucket = aws_s3_bucket.state.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnforceTLSRequestsOnly"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.state.arn,
          "${aws_s3_bucket.state.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# 5. Lifecycle Rule to Expire Noncurrent Versions of Objects in the S3 Bucket After X Days
resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket     = aws_s3_bucket.state.id
  depends_on = [aws_s3_bucket_versioning.state]

  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }
  }
}
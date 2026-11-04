output "s3_bucket_name" {
  description = "Name of the created S3 state bucket"
  value       = aws_s3_bucket.state.id
}

output "s3_bucket_arn" {
  description = "ARN of the created S3 state bucket"
  value       = aws_s3_bucket.state.arn
}

output "s3_bucket_region" {
  description = "AWS region where the state bucket is deployed"
  value       = aws_s3_bucket.state.region
}
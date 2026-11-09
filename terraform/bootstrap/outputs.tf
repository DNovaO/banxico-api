output "terraform_state_bucket" {
  description = "S3 bucket used to store Terraform state."
  value       = aws_s3_bucket.terraform_state.bucket
}

output "aws_account_id" {
  description = "AWS account ID used by this deployment."
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS region used by this deployment."
  value       = var.aws_region
}
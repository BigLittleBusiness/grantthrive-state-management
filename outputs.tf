output "terraform_state_backend_bucket" {
  value       = aws_s3_bucket.terraform_state_backend.id
  description = "S3 bucket for backend terraform state"
}

output "terraform_state_frontend_bucket" {
  value       = aws_s3_bucket.terraform_state_frontend.id
  description = "S3 bucket for frontend terraform state"
}

output "terraform_locks_table" {
  value       = aws_dynamodb_table.terraform_locks.name
  description = "DynamoDB table for state locking"
}

output "backend_config" {
  value = {
    bucket         = aws_s3_bucket.terraform_state_backend.id
    key            = "terraform.tfstate"
    region         = "ap-southeast-2"
    encrypt        = "true"
    dynamodb_table = aws_dynamodb_table.terraform_locks.name
  }
  description = "Backend configuration for grantthrive-platform terraform"
}

output "frontend_config" {
  value = {
    bucket         = aws_s3_bucket.terraform_state_frontend.id
    key            = "terraform.tfstate"
    region         = "ap-southeast-2"
    encrypt        = "true"
    dynamodb_table = aws_dynamodb_table.terraform_locks.name
  }
  description = "Backend configuration for GrantThrive-frontend terraform"
}

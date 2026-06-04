terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# S3 bucket for Terraform state - Backend
resource "aws_s3_bucket" "terraform_state_backend" {
  bucket = "grantthrive-terraform-state-backend-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "terraform-state-backend"
    Environment = "shared"
    ManagedBy   = "Terraform"
    Purpose     = "Terraform remote state for grantthrive-platform"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state_backend" {
  bucket = aws_s3_bucket.terraform_state_backend.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state_backend" {
  bucket = aws_s3_bucket.terraform_state_backend.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state_backend" {
  bucket = aws_s3_bucket.terraform_state_backend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "terraform_state_backend" {
  bucket = aws_s3_bucket.terraform_state_backend.id

  rule {
    id     = "delete-old-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# S3 bucket for Terraform state - Frontend
resource "aws_s3_bucket" "terraform_state_frontend" {
  bucket = "grantthrive-terraform-state-frontend-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "terraform-state-frontend"
    Environment = "shared"
    ManagedBy   = "Terraform"
    Purpose     = "Terraform remote state for GrantThrive-frontend"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state_frontend" {
  bucket = aws_s3_bucket.terraform_state_frontend.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state_frontend" {
  bucket = aws_s3_bucket.terraform_state_frontend.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state_frontend" {
  bucket = aws_s3_bucket.terraform_state_frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "terraform_state_frontend" {
  bucket = aws_s3_bucket.terraform_state_frontend.id

  rule {
    id     = "delete-old-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# DynamoDB table for state locking (optional but recommended)
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "grantthrive-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "terraform-locks"
    Environment = "shared"
    ManagedBy   = "Terraform"
    Purpose     = "State locking for concurrent Terraform operations"
  }
}

data "aws_caller_identity" "current" {}

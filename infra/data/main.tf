terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

locals {
  table_name  = var.orders_table
  bucket_name = var.archive_bucket

  # Console-style tags/names
  table_tags  = merge(var.tags, { Name = var.orders_table })
  bucket_tags = merge(var.tags, { Name = var.archive_bucket })
}

# -----------------------
# DynamoDB orders table
# -----------------------
resource "aws_dynamodb_table" "orders" {
  name         = local.table_name
  billing_mode = "PAY_PER_REQUEST"

  hash_key = var.dynamodb_pk_name

  attribute {
    name = var.dynamodb_pk_name
    type = var.dynamodb_pk_type
  }

  dynamic "attribute" {
    for_each = var.dynamodb_sk_name == "" ? [] : [1]
    content {
      name = var.dynamodb_sk_name
      type = "S"
    }
  }

  tags = local.table_tags
}

# -----------------------
# S3 archive bucket
# -----------------------
resource "aws_s3_bucket" "archive" {
  bucket = local.bucket_name
  tags   = local.bucket_tags
}

# Global best practices but still "simple"
resource "aws_s3_bucket_public_access_block" "archive" {
  bucket                  = aws_s3_bucket.archive.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "archive" {
  bucket = aws_s3_bucket.archive.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256" # SSE-S3
    }
  }
}

resource "aws_s3_bucket_versioning" "archive" {
  bucket = aws_s3_bucket.archive.id
  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

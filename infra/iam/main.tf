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

# Pull upstream state
data "terraform_remote_state" "data" {
  backend = "local"
  config  = { path = "../data/terraform.tfstate" }
}

data "terraform_remote_state" "messaging" {
  backend = "local"
  config  = { path = "../messaging/terraform.tfstate" }
}

locals {
  # Names
  publisher_role_name    = "${var.name_prefix}-lambda-publisher-role"
  ddb_consumer_role_name = "${var.name_prefix}-lambda-ddb-consumer-role"
  s3_consumer_role_name  = "${var.name_prefix}-lambda-s3-consumer-role"

  # Resources from prior steps
  topic_arn        = data.terraform_remote_state.messaging.outputs.orders_topic_arn
  billing_q_arn    = data.terraform_remote_state.messaging.outputs.billing_q_arn
  archive_q_arn    = data.terraform_remote_state.messaging.outputs.archive_q_arn
  table_arn        = data.terraform_remote_state.data.outputs.orders_table_arn
  bucket_arn       = data.terraform_remote_state.data.outputs.archive_bucket_arn

  # Common assume-role policy for Lambda
  lambda_assume_role = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

# --------------------------
# Publisher role (SNS:Publish)
# --------------------------
resource "aws_iam_role" "publisher" {
  name               = local.publisher_role_name
  assume_role_policy = local.lambda_assume_role
  tags               = merge(var.tags, { Name = local.publisher_role_name })
}

# Managed policies for logs + VPC ENI access
resource "aws_iam_role_policy_attachment" "publisher_logs" {
  role       = aws_iam_role.publisher.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
resource "aws_iam_role_policy_attachment" "publisher_vpc" {
  role       = aws_iam_role.publisher.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Custom inline: allow publish to our SNS topic
data "aws_iam_policy_document" "publisher_custom" {
  statement {
    sid     = "PublishOrdersTopic"
    effect  = "Allow"
    actions = ["sns:Publish"]
    resources = [local.topic_arn]
  }
}
resource "aws_iam_role_policy" "publisher_custom" {
  name   = "${var.name_prefix}-publisher-custom"
  role   = aws_iam_role.publisher.id
  policy = data.aws_iam_policy_document.publisher_custom.json
}

# ---------------------------------------
# DDB consumer role (SQS + DynamoDB Put)
# ---------------------------------------
resource "aws_iam_role" "ddb_consumer" {
  name               = local.ddb_consumer_role_name
  assume_role_policy = local.lambda_assume_role
  tags               = merge(var.tags, { Name = local.ddb_consumer_role_name })
}

resource "aws_iam_role_policy_attachment" "ddb_consumer_logs" {
  role       = aws_iam_role.ddb_consumer.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
resource "aws_iam_role_policy_attachment" "ddb_consumer_vpc" {
  role       = aws_iam_role.ddb_consumer.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

data "aws_iam_policy_document" "ddb_consumer_custom" {
  statement {
    sid    = "ConsumeFromBillingQueue"
    effect = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:ChangeMessageVisibility",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl"
    ]
    resources = [local.billing_q_arn]
  }

  statement {
    sid     = "WriteOrdersTable"
    effect  = "Allow"
    actions = ["dynamodb:PutItem"]
    resources = [local.table_arn]
  }
}
resource "aws_iam_role_policy" "ddb_consumer_custom" {
  name   = "${var.name_prefix}-ddb-consumer-custom"
  role   = aws_iam_role.ddb_consumer.id
  policy = data.aws_iam_policy_document.ddb_consumer_custom.json
}

# --------------------------------------
# S3 consumer role (SQS + S3 PutObject)
# --------------------------------------
resource "aws_iam_role" "s3_consumer" {
  name               = local.s3_consumer_role_name
  assume_role_policy = local.lambda_assume_role
  tags               = merge(var.tags, { Name = local.s3_consumer_role_name })
}

resource "aws_iam_role_policy_attachment" "s3_consumer_logs" {
  role       = aws_iam_role.s3_consumer.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
resource "aws_iam_role_policy_attachment" "s3_consumer_vpc" {
  role       = aws_iam_role.s3_consumer.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

data "aws_iam_policy_document" "s3_consumer_custom" {
  statement {
    sid    = "ConsumeFromArchiveQueue"
    effect = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:ChangeMessageVisibility",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl"
    ]
    resources = [local.archive_q_arn]
  }

  statement {
    sid     = "PutToArchiveBucket"
    effect  = "Allow"
    actions = ["s3:PutObject"]
    resources = ["${local.bucket_arn}/*"]
  }
}
resource "aws_iam_role_policy" "s3_consumer_custom" {
  name   = "${var.name_prefix}-s3-consumer-custom"
  role   = aws_iam_role.s3_consumer.id
  policy = data.aws_iam_policy_document.s3_consumer_custom.json
}

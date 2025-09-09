terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.4.0"
    }
  }
}

provider "aws" { region = var.region }

# ----- Pull upstream state -----
data "terraform_remote_state" "network" {
  backend = "local"
  config  = { path = "../network/terraform.tfstate" }
}
data "terraform_remote_state" "messaging" {
  backend = "local"
  config  = { path = "../messaging/terraform.tfstate" }
}
data "terraform_remote_state" "data" {
  backend = "local"
  config  = { path = "../data/terraform.tfstate" }
}
data "terraform_remote_state" "iam" {
  backend = "local"
  config  = { path = "../iam/terraform.tfstate" }
}

locals {
  # From network
  private_subnet_ids = data.terraform_remote_state.network.outputs.private_subnet_ids
  lambda_sg_id       = data.terraform_remote_state.network.outputs.lambda_sg_id

  # From messaging
  topic_arn     = data.terraform_remote_state.messaging.outputs.orders_topic_arn
  billing_q_arn = data.terraform_remote_state.messaging.outputs.billing_q_arn
  billing_q_url = data.terraform_remote_state.messaging.outputs.billing_q_url
  archive_q_arn = data.terraform_remote_state.messaging.outputs.archive_q_arn
  archive_q_url = data.terraform_remote_state.messaging.outputs.archive_q_url

  # From data
  table_name  = data.terraform_remote_state.data.outputs.orders_table_name
  table_arn   = data.terraform_remote_state.data.outputs.orders_table_arn
  bucket_name = data.terraform_remote_state.data.outputs.archive_bucket_name
  bucket_arn  = data.terraform_remote_state.data.outputs.archive_bucket_arn

  # From iam
  publisher_role_arn    = data.terraform_remote_state.iam.outputs.publisher_role_arn
  ddb_consumer_role_arn = data.terraform_remote_state.iam.outputs.ddb_consumer_role_arn
  s3_consumer_role_arn  = data.terraform_remote_state.iam.outputs.s3_consumer_role_arn

  # Names
  publisher_name    = "${var.name_prefix}-lambda-publisher"
  ddb_consumer_name = "${var.name_prefix}-lambda-ddb-consumer"
  s3_consumer_name  = "${var.name_prefix}-lambda-s3-consumer"
}

# ----- Package code (zip) -----
data "archive_file" "publisher_zip" {
  type        = "zip"
  source_dir  = var.publisher_src_dir
  output_path = "${path.module}/.dist/${local.publisher_name}.zip"
}

data "archive_file" "ddb_zip" {
  type        = "zip"
  source_dir  = var.ddb_consumer_src_dir
  output_path = "${path.module}/.dist/${local.ddb_consumer_name}.zip"
}

data "archive_file" "s3_zip" {
  type        = "zip"
  source_dir  = var.s3_consumer_src_dir
  output_path = "${path.module}/.dist/${local.s3_consumer_name}.zip"
}

# Ensure folder exists before creating zips
resource "null_resource" "dist_dir" {
  provisioner "local-exec" { command = "mkdir -p ${path.module}/.dist" }
}

# ----- CloudWatch log groups (optional: control retention) -----
resource "aws_cloudwatch_log_group" "publisher" {
  name              = "/aws/lambda/${local.publisher_name}"
  retention_in_days = 14
  tags              = var.tags
}
resource "aws_cloudwatch_log_group" "ddb_consumer" {
  name              = "/aws/lambda/${local.ddb_consumer_name}"
  retention_in_days = 14
  tags              = var.tags
}
resource "aws_cloudwatch_log_group" "s3_consumer" {
  name              = "/aws/lambda/${local.s3_consumer_name}"
  retention_in_days = 14
  tags              = var.tags
}

# ----- Lambdas -----
resource "aws_lambda_function" "publisher" {
  function_name = local.publisher_name
  role          = local.publisher_role_arn
  runtime       = var.runtime
  handler       = var.publisher_handler

  filename         = data.archive_file.publisher_zip.output_path
  source_code_hash = data.archive_file.publisher_zip.output_base64sha256

  vpc_config {
    subnet_ids         = local.private_subnet_ids
    security_group_ids = [local.lambda_sg_id]
  }

  environment {
    variables = {
      CLIENT_ID        = var.client_id
      CLIENT_SECRET    = var.client_secret
      ORDERS_TOPIC_ARN = local.topic_arn
      # Optional convenience:
      BILLING_QUEUE_URL = local.billing_q_url
      ARCHIVE_QUEUE_URL = local.archive_q_url
    }
  }

  depends_on = [null_resource.dist_dir, aws_cloudwatch_log_group.publisher]
  tags       = merge(var.tags, { Name = local.publisher_name })
}

resource "aws_lambda_function" "ddb_consumer" {
  function_name = local.ddb_consumer_name
  role          = local.ddb_consumer_role_arn
  runtime       = var.runtime
  handler       = var.ddb_handler

  filename         = data.archive_file.ddb_zip.output_path
  source_code_hash = data.archive_file.ddb_zip.output_base64sha256

  memory_size = var.consumer_memory
  timeout     = var.consumer_timeout

  vpc_config {
    subnet_ids         = local.private_subnet_ids
    security_group_ids = [local.lambda_sg_id]
  }

  environment {
    variables = {
      TABLE_NAME       = local.table_name
      ORDERS_TABLE_ARN = local.table_arn
    }
  }

  depends_on = [null_resource.dist_dir, aws_cloudwatch_log_group.ddb_consumer]
  tags       = merge(var.tags, { Name = local.ddb_consumer_name })
}

resource "aws_lambda_function" "s3_consumer" {
  function_name = local.s3_consumer_name
  role          = local.s3_consumer_role_arn
  runtime       = var.runtime
  handler       = var.s3_handler

  filename         = data.archive_file.s3_zip.output_path
  source_code_hash = data.archive_file.s3_zip.output_base64sha256

  memory_size = var.consumer_memory
  timeout     = var.consumer_timeout

  vpc_config {
    subnet_ids         = local.private_subnet_ids
    security_group_ids = [local.lambda_sg_id]
  }

  environment {
    variables = {
      BUCKET_NAME        = local.bucket_name
      ARCHIVE_BUCKET_ARN = local.bucket_arn
    }
  }

  depends_on = [null_resource.dist_dir, aws_cloudwatch_log_group.s3_consumer]
  tags       = merge(var.tags, { Name = local.s3_consumer_name })
}

# ----- SQS → Lambda event source mappings -----
resource "aws_lambda_event_source_mapping" "billing_to_ddb" {
  event_source_arn                   = local.billing_q_arn
  function_name                      = aws_lambda_function.ddb_consumer.arn
  batch_size                         = var.batch_size
  maximum_batching_window_in_seconds = var.max_batching_window_ms == 0 ? 0 : floor(var.max_batching_window_ms / 1000)
  function_response_types            = [] # keep simple; add "ReportBatchItemFailures" if you implement partial failures
}

resource "aws_lambda_event_source_mapping" "archive_to_s3" {
  event_source_arn                   = local.archive_q_arn
  function_name                      = aws_lambda_function.s3_consumer.arn
  batch_size                         = var.batch_size
  maximum_batching_window_in_seconds = var.max_batching_window_ms == 0 ? 0 : floor(var.max_batching_window_ms / 1000)
  function_response_types            = []
}

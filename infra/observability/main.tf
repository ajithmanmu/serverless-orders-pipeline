terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 5.0" }
  }
}
provider "aws" { region = var.region }

# Upstream state reads
data "terraform_remote_state" "messaging" {
  backend = "local"
  config  = { path = "../messaging/terraform.tfstate" }
}
data "terraform_remote_state" "compute" {
  backend = "local"
  config  = { path = "../compute/terraform.tfstate" }
}
data "terraform_remote_state" "frontend" {
  backend = "local"
  config  = { path = "../frontend/terraform.tfstate" }
}

locals {
  # SQS names (CloudWatch dimensions use QueueName, not ARN)
  billing_q_arn = data.terraform_remote_state.messaging.outputs.billing_q_arn
  archive_q_arn = data.terraform_remote_state.messaging.outputs.archive_q_arn

  billing_q_name = element(split(":", local.billing_q_arn), length(split(":", local.billing_q_arn)) - 1)
  archive_q_name = element(split(":", local.archive_q_arn), length(split(":", local.archive_q_arn)) - 1)

  # Lambda names (CloudWatch dimension = FunctionName)
  publisher_lambda_arn    = data.terraform_remote_state.compute.outputs.publisher_lambda_arn
  ddb_consumer_lambda_arn = data.terraform_remote_state.compute.outputs.ddb_consumer_lambda_arn
  s3_consumer_lambda_arn  = data.terraform_remote_state.compute.outputs.s3_consumer_lambda_arn

  publisher_lambda_name    = element(split(":", local.publisher_lambda_arn), length(split(":", local.publisher_lambda_arn)) - 1)
  ddb_consumer_lambda_name = element(split(":", local.ddb_consumer_lambda_arn), length(split(":", local.ddb_consumer_lambda_arn)) - 1)
  s3_consumer_lambda_name  = element(split(":", local.s3_consumer_lambda_arn), length(split(":", local.s3_consumer_lambda_arn)) - 1)

  # ALB metrics use LoadBalancer dimension with full lb name (app/<name>/<id>)
  alb_arn      = data.terraform_remote_state.frontend.outputs.alb_arn
  alb_fullname = element(split("/", replace(local.alb_arn, "arn:aws:elasticloadbalancing:${var.region}:", "")), 1)
  # Explanation: ALB CloudWatch dimension should be like "app/orders-alb/xxxxxxxxxxxxx"
}

# ------------- SQS Alarms -------------

resource "aws_cloudwatch_metric_alarm" "sqs_billing_backlog" {
  alarm_name          = "${var.name_prefix}-billing-q-backlog-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.evaluation_periods
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = var.period_seconds
  statistic           = "Sum"
  threshold           = var.sqs_high_backlog_threshold

  dimensions = { QueueName = local.billing_q_name }

  alarm_description  = "Billing queue has a high visible message backlog."
  treat_missing_data = "notBreaching"
  tags               = var.tags
}

resource "aws_cloudwatch_metric_alarm" "sqs_archive_backlog" {
  alarm_name          = "${var.name_prefix}-archive-q-backlog-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.evaluation_periods
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = var.period_seconds
  statistic           = "Sum"
  threshold           = var.sqs_high_backlog_threshold

  dimensions = { QueueName = local.archive_q_name }

  alarm_description  = "Archive queue has a high visible message backlog."
  treat_missing_data = "notBreaching"
  tags               = var.tags
}

resource "aws_cloudwatch_metric_alarm" "sqs_billing_dlq_nonzero" {
  alarm_name          = "${var.name_prefix}-billing-dlq-has-messages"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.evaluation_periods
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = var.period_seconds
  statistic           = "Sum"
  threshold           = var.dlq_nonzero_threshold

  # Dimension uses DLQ name – infer from ARN by replacing suffix
  dimensions = { QueueName = "${var.name_prefix}-billing-dlq" }

  alarm_description  = "Billing DLQ has messages."
  treat_missing_data = "notBreaching"
  tags               = var.tags
}

resource "aws_cloudwatch_metric_alarm" "sqs_archive_dlq_nonzero" {
  alarm_name          = "${var.name_prefix}-archive-dlq-has-messages"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.evaluation_periods
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = var.period_seconds
  statistic           = "Sum"
  threshold           = var.dlq_nonzero_threshold

  dimensions = { QueueName = "${var.name_prefix}-archive-dlq" }

  alarm_description  = "Archive DLQ has messages."
  treat_missing_data = "notBreaching"
  tags               = var.tags
}

# ------------- Lambda Alarms -------------

resource "aws_cloudwatch_metric_alarm" "lambda_publisher_errors" {
  alarm_name          = "${var.name_prefix}-publisher-errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.evaluation_periods
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = var.period_seconds
  statistic           = "Sum"
  threshold           = var.lambda_error_threshold
  dimensions          = { FunctionName = local.publisher_lambda_name }
  alarm_description   = "Publisher Lambda reporting errors."
  treat_missing_data  = "notBreaching"
  tags                = var.tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_ddb_errors" {
  alarm_name          = "${var.name_prefix}-ddb-consumer-errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.evaluation_periods
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = var.period_seconds
  statistic           = "Sum"
  threshold           = var.lambda_error_threshold
  dimensions          = { FunctionName = local.ddb_consumer_lambda_name }
  alarm_description   = "DDB consumer Lambda reporting errors."
  treat_missing_data  = "notBreaching"
  tags                = var.tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_s3_errors" {
  alarm_name          = "${var.name_prefix}-s3-consumer-errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.evaluation_periods
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = var.period_seconds
  statistic           = "Sum"
  threshold           = var.lambda_error_threshold
  dimensions          = { FunctionName = local.s3_consumer_lambda_name }
  alarm_description   = "S3 consumer Lambda reporting errors."
  treat_missing_data  = "notBreaching"
  tags                = var.tags
}

# ------------- ALB Alarms -------------

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${var.name_prefix}-alb-5xx"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.evaluation_periods
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = var.period_seconds
  statistic           = "Sum"
  threshold           = var.alb_5xx_threshold

  dimensions = {
    LoadBalancer = local.alb_fullname
  }

  alarm_description  = "ALB is returning 5XX responses."
  treat_missing_data = "notBreaching"
  tags               = var.tags
}

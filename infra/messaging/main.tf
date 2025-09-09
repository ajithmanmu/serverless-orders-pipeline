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

# -----------------
# SNS Topic
# -----------------
resource "aws_sns_topic" "orders" {
  name = var.topic_name
  tags = merge(var.tags, { Name = var.topic_name })
}

# -----------------
# SQS Dead-letter Queues
# -----------------
resource "aws_sqs_queue" "billing_dlq" {
  name                      = var.billing_dlq_name
  message_retention_seconds = var.message_retention_seconds
  tags                      = merge(var.tags, { Name = var.billing_dlq_name })
}

resource "aws_sqs_queue" "archive_dlq" {
  name                      = var.archive_dlq_name
  message_retention_seconds = var.message_retention_seconds
  tags                      = merge(var.tags, { Name = var.archive_dlq_name })
}

# -----------------
# SQS Primary Queues (with redrive to DLQs)
# -----------------
resource "aws_sqs_queue" "billing" {
  name                       = var.billing_q_name
  visibility_timeout_seconds = var.visibility_timeout_seconds
  message_retention_seconds  = var.message_retention_seconds

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.billing_dlq.arn
    maxReceiveCount     = var.max_receive_count
  })

  tags = merge(var.tags, { Name = var.billing_q_name })
}

resource "aws_sqs_queue" "archive" {
  name                       = var.archive_q_name
  visibility_timeout_seconds = var.visibility_timeout_seconds
  message_retention_seconds  = var.message_retention_seconds

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.archive_dlq.arn
    maxReceiveCount     = var.max_receive_count
  })

  tags = merge(var.tags, { Name = var.archive_q_name })
}

# -----------------
# Queue Policies: allow ONLY SNS topic to send messages
# -----------------
data "aws_iam_policy_document" "billing_from_sns" {
  statement {
    sid     = "Allow-SNS-SendMessage"
    effect  = "Allow"
    actions = ["sqs:SendMessage"]
    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }
    resources = [aws_sqs_queue.billing.arn]
    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_sns_topic.orders.arn]
    }
  }
}

resource "aws_sqs_queue_policy" "billing" {
  queue_url = aws_sqs_queue.billing.id
  policy    = data.aws_iam_policy_document.billing_from_sns.json
}

data "aws_iam_policy_document" "archive_from_sns" {
  statement {
    sid     = "Allow-SNS-SendMessage"
    effect  = "Allow"
    actions = ["sqs:SendMessage"]
    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }
    resources = [aws_sqs_queue.archive.arn]
    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_sns_topic.orders.arn]
    }
  }
}

resource "aws_sqs_queue_policy" "archive" {
  queue_url = aws_sqs_queue.archive.id
  policy    = data.aws_iam_policy_document.archive_from_sns.json
}

# -----------------
# Subscriptions: SNS → SQS
# -----------------
resource "aws_sns_topic_subscription" "billing" {
  topic_arn            = aws_sns_topic.orders.arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.billing.arn
  raw_message_delivery = var.raw_message_delivery
}

resource "aws_sns_topic_subscription" "archive" {
  topic_arn            = aws_sns_topic.orders.arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.archive.arn
  raw_message_delivery = var.raw_message_delivery
}

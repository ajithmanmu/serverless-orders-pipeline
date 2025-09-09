terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 5.0" }
  }
}

provider "aws" { region = var.region }

# Upstream state
data "terraform_remote_state" "network" {
  backend = "local"
  config  = { path = "../network/terraform.tfstate" }
}
data "terraform_remote_state" "compute" {
  backend = "local"
  config  = { path = "../compute/terraform.tfstate" }
}

locals {
  public_subnet_ids = data.terraform_remote_state.network.outputs.public_subnet_ids
  alb_sg_id         = data.terraform_remote_state.network.outputs.alb_sg_id

  publisher_lambda_arn = data.terraform_remote_state.compute.outputs.publisher_lambda_arn

  lb_name = "${var.name_prefix}-alb"
  tg_name = "${var.name_prefix}-lambda-publisher-tg"
}

# ------------------------
# Application Load Balancer
# ------------------------
resource "aws_lb" "this" {
  name               = local.lb_name
  load_balancer_type = "application"
  internal           = false

  subnets         = local.public_subnet_ids
  security_groups = [local.alb_sg_id]

  enable_deletion_protection = false

  tags = merge(var.tags, { Name = local.lb_name })
}

# --------------------------------
# Target Group (Lambda)
# --------------------------------
resource "aws_lb_target_group" "lambda_tg" {
  name        = local.tg_name
  target_type = "lambda"

  # For Lambda target groups you don't set port/protocol; ALB invokes the function.
  # Health checks are implicit via Lambda invocation result.

  tags = merge(var.tags, { Name = local.tg_name })
}

# Attach the publisher Lambda as a target
resource "aws_lb_target_group_attachment" "publisher" {
  target_group_arn = aws_lb_target_group.lambda_tg.arn
  target_id        = local.publisher_lambda_arn
  depends_on = [aws_lambda_permission.allow_alb]
}

# Allow ALB to invoke the Lambda
resource "aws_lambda_permission" "allow_alb" {
  statement_id  = "AllowExecutionFromALB"
  action        = "lambda:InvokeFunction"
  function_name = local.publisher_lambda_arn
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.lambda_tg.arn
}

# --------------------------------
# Listener + Rule for POST /orders
# --------------------------------
# Default: 404 for everything else (keeps demo tidy)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = var.listener_port
  protocol          = var.listener_protocol

  default_action {
    type = "fixed-response"
    fixed_response {
      status_code  = "404"
      content_type = "text/plain"
      message_body = "Not Found"
    }
  }
}

# Forward only when method=POST and path=/orders*
resource "aws_lb_listener_rule" "orders_post" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lambda_tg.arn
  }

  condition {
    path_pattern {
      values = ["/orders", "/orders/*"]
    }
  }

  condition {
    http_request_method {
      values = ["POST"]
    }
  }
}

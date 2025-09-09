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
  vpc_name          = "${var.name_prefix}-vpc"
  igw_name          = "${var.name_prefix}-internet-gateway"
  public_rt_name    = "${var.name_prefix}-web-public-route-table"
  private_rt_name   = "${var.name_prefix}-app-private-route-table"
  alb_sg_name       = "${var.name_prefix}-alb-sg"
  lambda_sg_name    = "${var.name_prefix}-lambda-sg"
  endpoints_sg_name = "${var.name_prefix}-endpoints-sg"

  public_subnet_names = [
    "${var.name_prefix}-web-public-subnet-1a",
    "${var.name_prefix}-web-public-subnet-1b",
  ]

  private_subnet_names = [
    "${var.name_prefix}-app-private-subnet-1a",
    "${var.name_prefix}-app-private-subnet-1b",
  ]
}

# --- VPC ---
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = merge(var.tags, { Name = local.vpc_name })
}

# --- Internet Gateway ---
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = local.igw_name })
}

# --- Public subnets (1a, 1b) ---
resource "aws_subnet" "public" {
  for_each = {
    a = { cidr = var.public_subnet_cidrs[0], az = var.az_names[0], name = local.public_subnet_names[0] }
    b = { cidr = var.public_subnet_cidrs[1], az = var.az_names[1], name = local.public_subnet_names[1] }
  }

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true
  tags                    = merge(var.tags, { Name = each.value.name })
}

# --- Private subnets (1a, 1b) ---
resource "aws_subnet" "private" {
  for_each = {
    a = { cidr = var.private_subnet_cidrs[0], az = var.az_names[0], name = local.private_subnet_names[0] }
    b = { cidr = var.private_subnet_cidrs[1], az = var.az_names[1], name = local.private_subnet_names[1] }
  }

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az
  tags              = merge(var.tags, { Name = each.value.name })
}

# --- Route Tables ---
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = local.public_rt_name })
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = local.private_rt_name })
}

# Default route to IGW for public RT
resource "aws_route" "public_default" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# Associate public subnets with public RT
resource "aws_route_table_association" "public_assoc" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# Associate private subnets with private RT (no NAT; endpoints come in Step 2)
resource "aws_route_table_association" "private_assoc" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

# --- Security Groups ---

# ALB SG: allow 80/443 from internet; all egress
resource "aws_security_group" "alb" {
  name        = local.alb_sg_name
  description = "ALB ingress"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = local.alb_sg_name })
}

# Lambda SG: no ingress; allow all egress (traffic will use VPC endpoints)
resource "aws_security_group" "lambda" {
  name        = local.lambda_sg_name
  description = "Lambda egress"
  vpc_id      = aws_vpc.this.id

  egress {
    description = "All egress (will rely on VPC endpoints for AWS service traffic)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = local.lambda_sg_name })
}

# Interface Endpoints SG: allow 443 from Lambda SG
resource "aws_security_group" "endpoints" {
  name        = local.endpoints_sg_name
  description = "Interface endpoints"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "HTTPS from Lambdas"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda.id]
  }

  egress {
    description = "All egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = local.endpoints_sg_name })
}

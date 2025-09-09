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

# Pull Step 1 outputs
data "terraform_remote_state" "network" {
  backend = "local"
  config  = {
    path = "../network/terraform.tfstate"
  }
}

locals {
  vpc_id               = data.terraform_remote_state.network.outputs.vpc_id
  private_subnet_ids   = data.terraform_remote_state.network.outputs.private_subnet_ids
  private_route_table  = data.terraform_remote_state.network.outputs.private_route_table_id
  endpoints_sg_id      = data.terraform_remote_state.network.outputs.endpoints_sg_id

  name_s3_gw   = "${var.name_prefix}-s3-gateway-endpoint"
  name_ddb_gw  = "${var.name_prefix}-dynamodb-gateway-endpoint"
  name_sqs_if  = "${var.name_prefix}-sqs-interface-endpoint"
  name_sns_if  = "${var.name_prefix}-sns-interface-endpoint"
  name_logs_if = "${var.name_prefix}-logs-interface-endpoint"
}

# --- Gateway Endpoints (attach to PRIVATE route table) ---

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = local.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [local.private_route_table]

  tags = merge(var.tags, { Name = local.name_s3_gw })
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = local.vpc_id
  service_name      = "com.amazonaws.${var.region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [local.private_route_table]

  tags = merge(var.tags, { Name = local.name_ddb_gw })
}

# --- Interface Endpoints (in PRIVATE subnets; SG = endpoints SG) ---

resource "aws_vpc_endpoint" "sqs" {
  vpc_id              = local.vpc_id
  service_name        = "com.amazonaws.${var.region}.sqs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.private_subnet_ids
  security_group_ids  = [local.endpoints_sg_id]
  private_dns_enabled = true

  tags = merge(var.tags, { Name = local.name_sqs_if })
}

resource "aws_vpc_endpoint" "sns" {
  vpc_id              = local.vpc_id
  service_name        = "com.amazonaws.${var.region}.sns"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.private_subnet_ids
  security_group_ids  = [local.endpoints_sg_id]
  private_dns_enabled = true

  tags = merge(var.tags, { Name = local.name_sns_if })
}

resource "aws_vpc_endpoint" "logs" {
  vpc_id              = local.vpc_id
  service_name        = "com.amazonaws.${var.region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.private_subnet_ids
  security_group_ids  = [local.endpoints_sg_id]
  private_dns_enabled = true

  tags = merge(var.tags, { Name = local.name_logs_if })
}

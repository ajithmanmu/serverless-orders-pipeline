variable "region" { type = string }
variable "vpc_cidr" { type = string }
variable "public_subnet_cidrs" { type = list(string) }  # [1a, 1b]
variable "private_subnet_cidrs" { type = list(string) } # [1a, 1b]
variable "az_names" { type = list(string) }             # ["us-east-1a","us-east-1b"]
variable "name_prefix" { type = string }                # "orders"
variable "tags" { type = map(string) }

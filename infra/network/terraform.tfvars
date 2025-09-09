region = "us-east-1"

vpc_cidr = "10.0.0.0/16"

public_subnet_cidrs = [
  "10.0.0.0/20", # 1a
  "10.0.16.0/20" # 1b
]

private_subnet_cidrs = [
  "10.0.32.0/20", # 1a
  "10.0.48.0/20"  # 1b
]

az_names    = ["us-east-1a", "us-east-1b"]
name_prefix = "orders"

tags = {
  Project   = "orders-pipeline"
  ManagedBy = "terraform"
}

region      = "us-east-1"
name_prefix = "orders"

orders_table   = "orders"
archive_bucket = "orders-archive-bucket-412602263780-us-east-1"

tags = {
  Project   = "orders-pipeline"
  ManagedBy = "terraform"
}

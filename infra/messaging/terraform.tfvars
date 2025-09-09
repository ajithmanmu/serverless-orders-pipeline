region      = "us-east-1"
name_prefix = "orders"

topic_name       = "orders-topic"
billing_q_name   = "orders-billing-q"
billing_dlq_name = "orders-billing-dlq"
archive_q_name   = "orders-archive-q"
archive_dlq_name = "orders-archive-dlq"

tags = {
  Project   = "orders-pipeline"
  ManagedBy = "terraform"
}

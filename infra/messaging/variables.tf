variable "region" { type = string }
variable "name_prefix" { type = string } # "orders"
variable "topic_name" { type = string }  # "orders-topic"

variable "billing_q_name" { type = string }   # "orders-billing-q"
variable "billing_dlq_name" { type = string } # "orders-billing-dlq"

variable "archive_q_name" { type = string }   # "orders-archive-q"
variable "archive_dlq_name" { type = string } # "orders-archive-dlq"

# Tuning knobs (simple sensible defaults)
variable "visibility_timeout_seconds" {
  type    = number
  default = 30
}
variable "message_retention_seconds" {
  type    = number
  default = 345600
} # 4 days
variable "max_receive_count" {
  type    = number
  default = 5
} # DLQ after 5 tries
variable "raw_message_delivery" {
  type    = bool
  default = true
}

variable "tags" { type = map(string) }

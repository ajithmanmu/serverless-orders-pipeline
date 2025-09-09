variable "region" { type = string }
variable "name_prefix" { type = string }    # "orders"
variable "orders_table" { type = string }   # e.g., "orders-table"
variable "archive_bucket" { type = string } # e.g., "orders-archive-bucket-<uniq>"
variable "tags" { type = map(string) }

# Optional: choose the partition/sort key names if you want to tweak later
variable "dynamodb_pk_name" {
  type    = string
  default = "orderId"
}
variable "dynamodb_pk_type" {
  type    = string
  default = "S"
} # "S" | "N" | "B"
variable "dynamodb_sk_name" {
  type    = string
  default = ""
} # leave empty = no sort key
variable "enable_versioning" {
  type    = bool
  default = false
}

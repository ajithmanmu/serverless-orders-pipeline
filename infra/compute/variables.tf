variable "region" { type = string }
variable "name_prefix" { type = string } # "orders"
variable "tags" { type = map(string) }

# Relative paths to your Lambda source folders
variable "publisher_src_dir" { type = string }    # e.g., "../../lambdas/publisher"
variable "ddb_consumer_src_dir" { type = string } # e.g., "../../lambdas/ddb-consumer"
variable "s3_consumer_src_dir" { type = string }  # e.g., "../../lambdas/s3-archive-consumer"

# Lambda runtime/handler
variable "runtime" {
  type    = string
  default = "python3.12"
}
variable "publisher_handler" {
  type    = string
  default = "app.lambda_handler"
}
variable "ddb_handler" {
  type    = string
  default = "app.lambda_handler"
}
variable "s3_handler" {
  type    = string
  default = "app.lambda_handler"
}

# Sizing
variable "publisher_memory" {
  type    = number
  default = 256
}
variable "publisher_timeout" {
  type    = number
  default = 10
}
variable "consumer_memory" {
  type    = number
  default = 256
}
variable "consumer_timeout" {
  type    = number
  default = 30
}

# SQS → Lambda mapping knobs
variable "batch_size" {
  type    = number
  default = 10
}
variable "max_batching_window_ms" {
  type    = number
  default = 0
} # 0 = immediate
variable "visibility_timeout" {
  type    = number
  default = 0
} # 0 = use queue setting

# Publisher auth/env
variable "client_id" { type = string }
variable "client_secret" { type = string }

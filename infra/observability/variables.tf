variable "region" { type = string }
variable "name_prefix" { type = string } # "orders"
variable "tags" { type = map(string) }

# Tunables (sane defaults)
variable "sqs_high_backlog_threshold" {
  type    = number
  default = 10
} # msgs visible
variable "dlq_nonzero_threshold" {
  type    = number
  default = 1
} # msgs visible
variable "lambda_error_threshold" {
  type    = number
  default = 1
} # errors
variable "alb_5xx_threshold" {
  type    = number
  default = 1
} # 5xx count
variable "evaluation_periods" {
  type    = number
  default = 1
}
variable "period_seconds" {
  type    = number
  default = 300
} # 5 min

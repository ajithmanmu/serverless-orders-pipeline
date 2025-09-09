variable "region" { type = string }
variable "name_prefix" { type = string } # "orders"
variable "tags" { type = map(string) }

# Listener settings (keep simple; HTTP only for now—no ACM cert)
variable "listener_port" {
  type    = number
  default = 80
}
variable "listener_protocol" {
  type    = string
  default = "HTTP"
}

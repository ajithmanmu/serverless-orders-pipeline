output "alb_dns_name" { value = aws_lb.this.dns_name }
output "alb_arn" { value = aws_lb.this.arn }
output "tg_arn" { value = aws_lb_target_group.lambda_tg.arn }
output "listener_arn" { value = aws_lb_listener.http.arn }

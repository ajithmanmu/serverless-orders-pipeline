output "orders_topic_arn" { value = aws_sns_topic.orders.arn }

output "billing_q_arn" { value = aws_sqs_queue.billing.arn }
output "billing_q_url" { value = aws_sqs_queue.billing.id }
output "billing_dlq_arn" { value = aws_sqs_queue.billing_dlq.arn }

output "archive_q_arn" { value = aws_sqs_queue.archive.arn }
output "archive_q_url" { value = aws_sqs_queue.archive.id }
output "archive_dlq_arn" { value = aws_sqs_queue.archive_dlq.arn }

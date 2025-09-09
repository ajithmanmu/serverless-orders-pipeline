output "orders_table_name" { value = aws_dynamodb_table.orders.name }
output "orders_table_arn" { value = aws_dynamodb_table.orders.arn }

output "archive_bucket_name" { value = aws_s3_bucket.archive.bucket }
output "archive_bucket_arn" { value = aws_s3_bucket.archive.arn }

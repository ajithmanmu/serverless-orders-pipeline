output "publisher_lambda_arn" { value = aws_lambda_function.publisher.arn }
output "ddb_consumer_lambda_arn" { value = aws_lambda_function.ddb_consumer.arn }
output "s3_consumer_lambda_arn" { value = aws_lambda_function.s3_consumer.arn }

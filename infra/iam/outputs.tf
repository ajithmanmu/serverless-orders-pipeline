output "publisher_role_arn"     { value = aws_iam_role.publisher.arn }
output "ddb_consumer_role_arn"  { value = aws_iam_role.ddb_consumer.arn }
output "s3_consumer_role_arn"   { value = aws_iam_role.s3_consumer.arn }

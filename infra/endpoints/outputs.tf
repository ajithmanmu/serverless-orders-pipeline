output "s3_gateway_endpoint_id"       { value = aws_vpc_endpoint.s3.id }
output "dynamodb_gateway_endpoint_id" { value = aws_vpc_endpoint.dynamodb.id }

output "sqs_interface_endpoint_id"  { value = aws_vpc_endpoint.sqs.id }
output "sns_interface_endpoint_id"  { value = aws_vpc_endpoint.sns.id }
output "logs_interface_endpoint_id" { value = aws_vpc_endpoint.logs.id }

# Handy map if you want to consume as a set later
output "vpce_ids" {
  value = {
    sqs  = aws_vpc_endpoint.sqs.id
    sns  = aws_vpc_endpoint.sns.id
    logs = aws_vpc_endpoint.logs.id
  }
}

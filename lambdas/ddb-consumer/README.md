# orders-ddb-consumer (SQS → DynamoDB)

Minimal Lambda consumer that reads SQS messages (from an SNS topic subscription),
unwraps the SNS envelope (handles base64 + JSON), and writes each order into a
DynamoDB table.

## Env Vars
- `ORDERS_TABLE` — DynamoDB table name (default: `orders`)

## IAM (attach to the function's execution role)
- `AWSLambdaBasicExecutionRole`
- `policy.sqs.json` — scoped to your queue ARN
- `policy.dynamodb.json` — scoped to your `orders` table ARN

## VPC
- Subnets: private app subnets (2 AZs)
- Security group: `orders-lambda-sg` (egress 443)

## Trigger
- Source: your SQS queue
- Batch size: 10
- **Enable** "Report batch item failures"

## Notes
- Numbers are parsed as `Decimal` to satisfy DynamoDB (no Python `float`).
- If you enable **Raw message delivery** on the SNS→SQS subscription, the code
  will still work (it detects absence of the envelope).

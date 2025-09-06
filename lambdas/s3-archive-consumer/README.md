# orders-s3-consumer (SQS → S3 archive)

Consumes SQS messages (from SNS), unwraps SNS envelope (handles base64/JSON),
and writes each payload as a JSON object to S3 with SSE-S3 enabled.

## Env
- `ARCHIVE_BUCKET` (required)
- `ARCHIVE_PREFIX` (optional, default `orders/`)

## IAM (attach to function role)
- `AWSLambdaBasicExecutionRole`
- `policy.sqs.json` (queue-scoped)
- `policy.s3.json` (bucket-scoped)

## VPC
- Private app subnets, SG with egress 443 (to VPC endpoints)

## Trigger
- SQS archive queue, batch size 10, **Report batch item failures** enabled

## Object keys
`<PREFIX><YYYY>/<MM>/<DD>/<orderId or messageId>/<epoch_ms>.json`

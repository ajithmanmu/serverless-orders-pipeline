# orders-lambda-publisher (ALB → Lambda → SNS)

Accepts `POST /orders` from an internet-facing ALB, verifies HMAC headers,
and publishes the request body to an SNS topic (fan-out to SQS consumers).

## Env Vars
- `ORDERS_TOPIC_ARN` — ARN of your SNS topic (`orders-topic`)
- `SHARED_SECRET` — shared HMAC secret (move to Secrets Manager later if desired)

## Auth (HMAC)
- Required headers:
  - `X-Client-Id`
  - `X-Signature` = `hex(hmac_sha256(SHARED_SECRET, raw_request_body))`

## Response
- `200 {"ok": true, "published": true}` on success
- `401` if headers/signature missing/invalid
- `404` for non-`POST /orders` (optional guard)

## ALB Setup
- Target group: **Lambda**
- Listener (80/443): forward `/orders` to the Lambda TG
- Lambda may be VPC-attached; ALB invokes via control plane (no inbound SG needed)

## Test (compute signature then curl)
```bash
# Replace the secret and ALB DNS
SECRET='your-long-random-string'
BODY='{"orderId":"o-5001","total":42}'
SIG=$(python - <<PY
import hmac, hashlib, os
print(hmac.new(b"${SECRET}".encode() if isinstance("${SECRET}", str) else b"${SECRET}", b'''${BODY}''', hashlib.sha256).hexdigest())
PY
)

curl -i -X POST "http://<ALB-DNS>/orders" \
  -H "Content-Type: application/json" \
  -H "X-Client-Id: demo" \
  -H "X-Signature: $SIG" \
  -d "${BODY}"

# serverless-orders-pipeline
Serverless Orders Pipeline on AWS (SNS + SQS + Lambda)

Sample Request:

```
SIG=$(python3 - <<'PY'
import hmac, hashlib, sys
secret=b'demo-client-secret'
body=b'{"orderId":"o-7001","total":30}'
print(hmac.new(secret, body, hashlib.sha256).hexdigest())
PY
)

curl -i -X POST "http://orders-alb-199622624.us-east-1.elb.amazonaws.com/orders" \
  -H "Content-Type: application/json" \
  -H "X-Client-Id: demo-client-id" \
  -H "X-Signature: $SIG" \
  -d '{"orderId":"o-7001","total":30}'
```

```
curl -i -X POST "http://orders-alb-199622624.us-east-1.elb.amazonaws.com/orders" \
  -H "Content-Type: application/json" \
  -H "X-Client-Id: demo-client-id" \
  -H "X-Signature: demo-client-secret" \
  -d '{"orderId":"demo-001","items":[{"sku":"abc","qty":1}]}'
```
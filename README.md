# serverless-orders-pipeline
Serverless Orders Pipeline on AWS (SNS + SQS + Lambda)

Sample Request:

```
SIG=$(python3 - <<'PY'
import hmac, hashlib, sys
secret=b'Kqi7kK$Hz%LN8M'
body=b'{"orderId":"o-5001","total":1142}'
print(hmac.new(secret, body, hashlib.sha256).hexdigest())
PY
)

curl -i -X POST "http://orders-alb-1170053028.us-east-1.elb.amazonaws.com/orders" \
  -H "Content-Type: application/json" \
  -H "X-Client-Id: demo" \
  -H "X-Signature: $SIG" \
  -d '{"orderId":"o-5001","total":1142}'
```
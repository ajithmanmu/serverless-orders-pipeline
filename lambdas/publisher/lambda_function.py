import os
import json
import base64
import hmac
import hashlib
import boto3

# Env vars (configure in Lambda console)
TOPIC_ARN = os.environ["ORDERS_TOPIC_ARN"]     # arn:aws:sns:region:acct:orders-topic
CLIENT_SECRET = os.environ["CLIENT_SECRET"].encode("utf-8")

sns = boto3.client("sns")


def _decode_body(event) -> bytes:
    """Return the raw request body as bytes, handling ALB base64 encoding."""
    body = event.get("body")
    if body is None:
        return b""
    if event.get("isBase64Encoded"):
        return base64.b64decode(body)
    if isinstance(body, str):
        return body.encode("utf-8")
    return bytes(body)


def _auth_ok(headers: dict, raw_body: bytes) -> bool:
    """HMAC-SHA256 over the raw request body using CLIENT_SECRET."""
    client_id = headers.get("x-client-id")
    sig = headers.get("x-signature")
    if not client_id or not sig:
        return False
    mac = hmac.new(CLIENT_SECRET, raw_body, hashlib.sha256).hexdigest()
    return hmac.compare_digest(mac, sig)


def _resp(status: int, obj: dict):
    # ALB Lambda target response format
    return {
        "statusCode": status,
        "statusDescription": f"{status} {'OK' if status == 200 else ''}".strip(),
        "isBase64Encoded": False,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(obj),
    }


def lambda_handler(event, context):
    # Normalize headers to lowercase keys
    headers = { (k or "").lower(): v for k, v in (event.get("headers") or {}).items() }

    # Minimal route/method guard (optional; ALB listener rule may already route /orders)
    if event.get("path") != "/orders" or event.get("httpMethod") != "POST":
        return _resp(404, {"error": "not found"})

    raw_body = _decode_body(event)

    # HMAC auth
    if not _auth_ok(headers, raw_body):
        return _resp(401, {"error": "unauthorized"})

    # Preserve JSON if possible; otherwise publish as UTF-8 text
    try:
        payload = json.loads(raw_body.decode("utf-8"))
        message = json.dumps(payload)
    except Exception:
        message = raw_body.decode("utf-8", errors="replace")

    # Publish to SNS
    sns.publish(TopicArn=TOPIC_ARN, Message=message)

    return _resp(200, {"ok": True, "published": True})

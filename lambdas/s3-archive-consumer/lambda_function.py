import os
import json
import time
import base64
import logging
from datetime import datetime, timezone

import boto3
from botocore.exceptions import ClientError

log = logging.getLogger()
log.setLevel(logging.INFO)

BUCKET = os.environ["ARCHIVE_BUCKET"]
PREFIX = os.environ.get("ARCHIVE_PREFIX", "orders/")

s3 = boto3.client("s3")

def _parse_sns_sqs_record(body: str):
    """
    Handles:
      • SNS→SQS envelope (outer JSON with 'Message' which may be base64 or JSON)
      • Raw delivery (body is already your payload)
    Returns: (payload_dict, order_id_fallback_str)
    """
    # Try loading as outer envelope first
    try:
        outer = json.loads(body)
    except Exception:
        # Not JSON at all – store raw text
        return {"raw": body}, None

    if "Message" not in outer:
        # Raw message delivery: outer is the payload
        return outer, str(outer.get("orderId") or outer.get("id") or None)

    msg = outer.get("Message")
    # Try base64 then JSON
    try:
        decoded = base64.b64decode(msg).decode("utf-8")
        try:
            payload = json.loads(decoded)
            return payload, str(payload.get("orderId") or payload.get("id") or None)
        except Exception:
            return {"raw": decoded}, None
    except Exception:
        try:
            payload = json.loads(msg)
            return payload, str(payload.get("orderId") or payload.get("id") or None)
        except Exception:
            return {"raw": msg}, None

def _object_key(order_id: str | None, message_id: str) -> str:
    # Key format: <PREFIX><YYYY/MM/DD>/<orderId or msgId>/<epoch_ms>.json
    now = datetime.now(timezone.utc)
    date_path = now.strftime("%Y/%m/%d")
    ts_ms = int(time.time() * 1000)
    leaf = order_id if (order_id and order_id != "None") else message_id
    return f"{PREFIX}{date_path}/{leaf}/{ts_ms}.json"

def lambda_handler(event, context):
    failures = []
    records = event.get("Records", [])
    log.info("Archiving %d records to s3://%s/%s", len(records), BUCKET, PREFIX)

    for rec in records:
        msg_id = rec["messageId"]
        try:
            payload, maybe_order_id = _parse_sns_sqs_record(rec.get("body", ""))
            key = _object_key(maybe_order_id, msg_id)

            s3.put_object(
                Bucket=BUCKET,
                Key=key,
                Body=json.dumps(payload, separators=(",", ":"), ensure_ascii=False).encode("utf-8"),
                ContentType="application/json",
                ServerSideEncryption="AES256",  # SSE-S3
            )
            log.info("PutObject OK key=%s", key)

        except ClientError as e:
            log.error("PutObject ClientError msgId=%s err=%s", msg_id, e.response.get("Error"))
            failures.append({"itemIdentifier": msg_id})
        except Exception:
            log.exception("Unexpected error msgId=%s", msg_id)
            failures.append({"itemIdentifier": msg_id})

    return {"batchItemFailures": failures}

import os
import json
import time
import base64
import logging
from decimal import Decimal

import boto3
from botocore.exceptions import ClientError

# Logging
log = logging.getLogger()
log.setLevel(logging.INFO)

# Env
TABLE_NAME = os.environ.get("ORDERS_TABLE", "orders")

# AWS clients/resources
dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(TABLE_NAME)


def _json_loads_decimal(s: str):
    """Parse JSON with numbers as Decimal so DynamoDB accepts them (no float)."""
    return json.loads(s, parse_float=Decimal, parse_int=Decimal)


def _parse_sns_sqs_record(body: str):
    """
    Handles both cases:
      • SNS→SQS envelope (outer JSON with 'Message' which may be base64 or JSON)
      • Raw delivery (body is already your payload)
    Returns: dict payload with Decimals where appropriate; else {"raw": "..."}.
    """
    try:
        outer = _json_loads_decimal(body)
    except Exception:
        return {"raw": body}

    # If this isn't an SNS envelope, it's the raw payload.
    if "Message" not in outer:
        return outer

    msg = outer.get("Message")

    # Try base64 first (covers ALB base64 bodies forwarded through publisher)
    try:
        decoded = base64.b64decode(msg).decode("utf-8")
        try:
            return _json_loads_decimal(decoded)
        except Exception:
            return {"raw": decoded}
    except Exception:
        # Not base64; try JSON
        try:
            return _json_loads_decimal(msg)
        except Exception:
            return {"raw": msg}


def lambda_handler(event, context):
    """
    SQS batch → for each record, unwrap payload and write:
      { orderId, payload, source="ddb-consumer", ts }
    Uses partial-batch failures so only bad records are retried/DLQ'ed.
    """
    failures = []
    records = event.get("Records", [])
    log.info("Region=%s Table=%s Records=%d",
             os.environ.get("AWS_REGION"), TABLE_NAME, len(records))

    for rec in records:
        msg_id = rec["messageId"]
        try:
            payload = _parse_sns_sqs_record(rec.get("body", ""))
            order_id = str(payload.get("orderId") or payload.get("id") or msg_id)

            item = {
                "orderId": order_id,
                "payload": payload,  # may contain Decimals
                "source": "ddb-consumer",
                "ts": int(time.time() * 1000)
            }

            resp = table.put_item(Item=item)
            log.info("PutItem OK orderId=%s http=%s",
                     order_id, resp.get("ResponseMetadata", {}).get("HTTPStatusCode"))

        except ClientError as e:
            log.error("PutItem ClientError msgId=%s err=%s",
                      msg_id, e.response.get("Error"))
            failures.append({"itemIdentifier": msg_id})
        except Exception:
            log.exception("Unexpected error msgId=%s", msg_id)
            failures.append({"itemIdentifier": msg_id})

    # If you enabled "Report batch item failures" on the trigger,
    # SQS will only retry items we return here.
    return {"batchItemFailures": failures}

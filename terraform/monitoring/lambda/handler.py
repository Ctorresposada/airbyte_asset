import json
import logging
import os

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

_sns = None


def _get_sns():
    global _sns
    if _sns is None:
        _sns = boto3.client("sns", region_name=os.environ["AWS_REGION"])
    return _sns


def _publish(topic_arn, subject, message):
    _get_sns().publish(TopicArn=topic_arn, Subject=subject, Message=message)


def lambda_handler(event, context):
    raw_body = event.get("body") or ""
    logger.info("Received webhook payload: %s", raw_body)

    critical_arn = os.environ["CRITICAL_TOPIC_ARN"]
    warning_arn = os.environ["WARNING_TOPIC_ARN"]

    if not raw_body:
        _publish(warning_arn, "Unparseable webhook payload", raw_body)
        return {"statusCode": 200, "body": "OK"}

    try:
        payload = json.loads(raw_body)
    except (json.JSONDecodeError, ValueError):
        _publish(warning_arn, "Unparseable webhook payload", raw_body)
        return {"statusCode": 200, "body": "OK"}

    data = payload.get("data")
    if not data or data.get("success") is None:
        _publish(warning_arn, "Unknown payload structure", raw_body)
        return {"statusCode": 200, "body": "OK"}

    if data["success"] is True:
        logger.info("Sync succeeded for connection=%s jobId=%s", data.get("connection", {}).get("name"), data.get("jobId"))
        return {"statusCode": 200, "body": "OK"}

    # success is False
    # connectionName is not a top-level data key — derive it from connection.name
    msg = {}
    connection = data.get("connection") or {}
    if connection.get("name"):
        msg["connectionName"] = connection["name"]
    for key in ("jobId", "errorMessage", "errorType", "errorOrigin", "startedAt", "finishedAt", "durationFormatted"):
        if data.get(key) is not None:
            msg[key] = data[key]

    connection_name = msg.get("connectionName", "unknown")
    _publish(critical_arn, f"Airbyte sync failed: {connection_name}", json.dumps(msg))
    return {"statusCode": 200, "body": "OK"}

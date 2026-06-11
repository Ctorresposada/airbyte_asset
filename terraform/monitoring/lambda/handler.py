import json
import logging
import os
import re

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


def _strip_mrkdwn_link(text):
    # <url|name> -> name; bare <url> -> url
    text = re.sub(r"<[^|>]+\|([^>]+)>", r"\1", text)
    text = re.sub(r"<([^>]+)>", r"\1", text)
    return text


def _strip_bold(text):
    return re.sub(r"\*([^*]+)\*", r"\1", text)


def _clean(text):
    return _strip_bold(_strip_mrkdwn_link(text)).strip()


def _build_sync_message(data, failed):
    lines = []

    def line(label, value):
        if value is not None and value != "":
            lines.append(f"{label:<14}{value}")

    connection = data.get("connection") or {}
    source = data.get("source") or {}
    destination = data.get("destination") or {}

    conn_name = connection.get("name", "")
    conn_url = connection.get("url", "")
    line("Connection:", f"{conn_name} ({conn_url})" if conn_url else conn_name)

    src_name = source.get("name", "")
    src_url = source.get("url", "")
    line("Source:", f"{src_name} ({src_url})" if src_url else src_name)

    dst_name = destination.get("name", "")
    dst_url = destination.get("url", "")
    line("Destination:", f"{dst_name} ({dst_url})" if dst_url else dst_name)

    line("Job ID:", data.get("jobId"))
    line("Started:", data.get("startedAt"))
    line("Finished:", data.get("finishedAt"))
    line("Duration:", data.get("durationFormatted"))

    records_emitted = data.get("recordsEmitted")
    records_committed = data.get("recordsCommitted")
    if records_emitted is not None and records_committed is not None:
        line("Records:", f"{records_emitted} emitted / {records_committed} committed")

    bytes_emitted = data.get("bytesEmittedFormatted")
    bytes_committed = data.get("bytesCommittedFormatted")
    if bytes_emitted is not None and bytes_committed is not None:
        line("Bytes:", f"{bytes_emitted} emitted / {bytes_committed} committed")

    if failed:
        line("Error:", data.get("errorMessage"))
        line("Type:", data.get("errorType"))
        line("Origin:", data.get("errorOrigin"))

    return "\n".join(lines)


def _extract_blocks_fields(blocks):
    title = ""
    source_name = ""
    destination_name = ""
    duration = ""
    failure_reason = ""
    sync_summary = ""

    if blocks and len(blocks) > 0:
        try:
            title = _clean(blocks[0]["text"]["text"])
        except (KeyError, TypeError, IndexError):
            pass

    if blocks and len(blocks) > 2:
        try:
            fields = blocks[2]["fields"]
            # alternating label/value pairs: Source label, Source value, Dest label, Dest value, Duration label, Duration value
            if len(fields) >= 2:
                source_name = _clean(fields[1]["text"])
            if len(fields) >= 4:
                destination_name = _clean(fields[3]["text"])
            if len(fields) >= 6:
                duration = _clean(fields[5]["text"])
        except (KeyError, TypeError, IndexError):
            pass

    if blocks and len(blocks) > 3:
        try:
            raw = blocks[3]["text"]["text"]
            # strip "*Failure reason:*\n\n```\n...\n```\n" wrapper
            raw = re.sub(r"\*Failure reason:\*\s*\n+```\s*\n?", "", raw)
            raw = re.sub(r"\n?```\s*$", "", raw).strip()
            failure_reason = _clean(raw)
        except (KeyError, TypeError, IndexError):
            pass

    if blocks and len(blocks) > 4:
        try:
            raw = blocks[4]["text"]["text"]
            raw = re.sub(r"\*Sync Summary:\*\s*\n?", "", raw).strip()
            sync_summary = _clean(raw)
        except (KeyError, TypeError, IndexError):
            pass

    return title, source_name, destination_name, duration, failure_reason, sync_summary


def _build_slack_message(payload):
    blocks = payload.get("blocks")
    if not blocks:
        return payload.get("text", "")

    title, source_name, destination_name, duration, failure_reason, sync_summary = _extract_blocks_fields(blocks)

    parts = []
    if title:
        parts.append(title)

    detail_lines = []
    if source_name:
        detail_lines.append(f"{'Source:':<14}{source_name}")
    if destination_name:
        detail_lines.append(f"{'Destination:':<14}{destination_name}")
    if duration:
        detail_lines.append(f"{'Duration:':<14}{duration}")
    if detail_lines:
        parts.append("\n" + "\n".join(detail_lines))

    if failure_reason:
        parts.append("\nFailure Reason:\n" + failure_reason)

    if sync_summary:
        parts.append("\nSync Summary:\n" + sync_summary)

    return "\n".join(parts)


def _connection_name_from_blocks(blocks):
    if not blocks:
        return ""
    try:
        title = _clean(blocks[0]["text"]["text"])
        # title is e.g. "Warning - repeated connection failures: Test Connection"
        # extract the part after the last ": " as the connection name
        if ": " in title:
            return title.rsplit(": ", 1)[-1]
        return title
    except (KeyError, TypeError, IndexError):
        return ""


def lambda_handler(event, context):
    raw_body = event.get("body") or ""
    logger.info("Received webhook payload: %s", raw_body)

    critical_arn = os.environ["CRITICAL_TOPIC_ARN"]
    warning_arn = os.environ["WARNING_TOPIC_ARN"]

    if not raw_body:
        _publish(warning_arn, "Airbyte | Unknown Notification", raw_body)
        return {"statusCode": 200, "body": "OK"}

    try:
        payload = json.loads(raw_body)
    except (json.JSONDecodeError, ValueError):
        _publish(warning_arn, "Airbyte | Unknown Notification", raw_body)
        return {"statusCode": 200, "body": "OK"}

    data = payload.get("data")

    if data is not None:
        success = data.get("success")
        connection = data.get("connection") or {}
        conn_name = connection.get("name", "unknown")

        if success is False:
            subject = f"Airbyte | Sync Failed: {conn_name}"
            message = _build_sync_message(data, failed=True)
            _publish(critical_arn, subject, message)
        elif success is True:
            subject = f"Airbyte | Sync Succeeded: {conn_name}"
            message = _build_sync_message(data, failed=False)
            _publish(warning_arn, subject, message)
        else:
            _publish(warning_arn, "Airbyte | Unknown Notification", raw_body)

        return {"statusCode": 200, "body": "OK"}

    text = payload.get("text", "")
    blocks = payload.get("blocks")

    if text and "text" in payload and data is None:
        if "disabled" in text.lower():
            conn_name = _connection_name_from_blocks(blocks)
            subject = f"Airbyte | Connection Disabled: {conn_name}" if conn_name else "Airbyte | Connection Disabled"
            message = _build_slack_message(payload)
            _publish(critical_arn, subject, message)
        elif blocks:
            conn_name = _connection_name_from_blocks(blocks)
            subject = f"Airbyte | Repeated Failures: {conn_name}" if conn_name else "Airbyte | Repeated Failures"
            message = _build_slack_message(payload)
            _publish(warning_arn, subject, message)
        else:
            message = text
            _publish(warning_arn, "Airbyte | Connection Update", message)

        return {"statusCode": 200, "body": "OK"}

    _publish(warning_arn, "Airbyte | Unknown Notification", raw_body)
    return {"statusCode": 200, "body": "OK"}

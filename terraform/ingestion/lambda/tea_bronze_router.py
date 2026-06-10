"""
tea_bronze_router.py — Lambda that routes files from raw/tea/ to bronze/tea/<subfolder>/.

Routing rules (evaluated in order):
  1. .pdf extension           → bronze/tea/<FY-folder>/pdfs/<filename>
  2. .csv with > 1200 columns → bronze/tea/<FY-folder>/wide_tables/<filename>
  3. .csv with ≤ 1200 columns → bronze/tea/<FY-folder>/<table_name>/<filename>
  4. anything else            → bronze/tea/<FY-folder>/other/<filename>

Table name derivation (for narrow CSVs):
  - Strip extension
  - Remove a leading 4-digit year followed by spaces or dashes
  - Lowercase
  - Replace runs of non-alphanumeric characters with a single underscore
  - Strip leading/trailing underscores

Invocation modes:
  S3 event mode  — event["Records"] list; routes each object, re-raises on failure.
  Backfill mode  — event["backfill"] == True; lists raw/tea/, skips keys already in
                   bronze (head_object check), copies the rest. Returns a stats dict.

Environment variables:
  RAW_BUCKET    — name of the source S3 bucket
  BRONZE_BUCKET — name of the destination S3 bucket

Copy strategy: s3.copy_object (server-side, same-account) — data never transits Lambda.
"""

import csv
import io
import logging
import os
import re
import urllib.parse

import boto3
from botocore.exceptions import ClientError

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# ---------------------------------------------------------------------------
# AWS clients (module-level for connection reuse across warm invocations)
# ---------------------------------------------------------------------------
s3 = boto3.client("s3")

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
RAW_BUCKET = os.environ["RAW_BUCKET"]
BRONZE_BUCKET = os.environ["BRONZE_BUCKET"]

# Number of bytes to fetch for column counting — enough to hold the first
# header line of even the widest TEA CSV files (which can exceed 1000 columns).
HEADER_FETCH_BYTES = 65536

# Column threshold that separates "wide" tables from "narrow" tables.
WIDE_COLUMN_THRESHOLD = 1200


# ---------------------------------------------------------------------------
# Routing helpers
# ---------------------------------------------------------------------------

def _derive_table_name(filename_no_ext: str) -> str:
    """
    Convert a filename stem to a clean Glue-compatible table name.

    Steps:
      1. Remove a leading 4-digit year followed by optional spaces or dashes.
      2. Lowercase the result.
      3. Replace runs of non-alphanumeric characters with a single underscore.
      4. Strip leading/trailing underscores.

    Examples:
      "2025 Campus STAAR Grade 3"                       → "campus_staar_grade_3"
      "2025-additional-targeted-support"                 → "additional_targeted_support"
      "multi-year-unacceptable-list-2025-after-2025-appeal" → "multi_year_unacceptable_list_2025_after_2025_appeal"
    """
    # Strip a leading 4-digit year plus any immediately following spaces or dashes.
    name = re.sub(r"^\d{4}[\s\-]+", "", filename_no_ext)
    name = name.lower()
    # Collapse any run of non-alphanumeric chars to a single underscore.
    name = re.sub(r"[^a-z0-9]+", "_", name)
    name = name.strip("_")
    return name


def _count_csv_columns(bucket: str, key: str) -> int:
    """
    Return the number of columns in the CSV by reading only the first
    HEADER_FETCH_BYTES bytes via an S3 Range GET.

    Raises ValueError if no header row can be parsed.
    """
    response = s3.get_object(
        Bucket=bucket,
        Key=key,
        Range=f"bytes=0-{HEADER_FETCH_BYTES - 1}",
    )
    raw_bytes = response["Body"].read()

    # Decode with errors="replace" so a partial multi-byte character at the
    # boundary does not throw UnicodeDecodeError.
    text = raw_bytes.decode("utf-8", errors="replace")

    # Take only the first line — the header.
    first_line = text.splitlines()[0] if text else ""
    if not first_line:
        raise ValueError(f"Could not read a header line from s3://{bucket}/{key}")

    reader = csv.reader(io.StringIO(first_line))
    columns = next(reader)
    return len(columns)


def _parse_raw_key(raw_key: str):
    """
    Parse a raw S3 key of the form  tea/<FY-folder>/[<subfolder>/]<filename>
    and return (fy_folder, filename).

    parts[0] = "tea"
    parts[1] = FY folder (e.g. "2024-2025")
    parts[-1] = filename
    """
    parts = raw_key.split("/")
    if len(parts) < 3:
        raise ValueError(
            f"Unexpected raw key structure (expected tea/<FY>/<file>): {raw_key}"
        )
    fy_folder = parts[1]
    filename = parts[-1]
    return fy_folder, filename


def _destination_key(raw_key: str) -> str:
    """
    Determine the bronze destination key for a given raw key.
    """
    fy_folder, filename = _parse_raw_key(raw_key)
    name, _, ext = filename.rpartition(".")
    ext_lower = ext.lower() if ext else ""

    if ext_lower == "pdf":
        subfolder = "pdfs"
        logger.info("Routing %s → pdfs/", filename)
    elif ext_lower == "csv":
        col_count = _count_csv_columns(RAW_BUCKET, raw_key)
        logger.info("CSV %s has %d columns", filename, col_count)
        if col_count > WIDE_COLUMN_THRESHOLD:
            subfolder = "wide_tables"
        else:
            table_name = _derive_table_name(name)
            subfolder = table_name
    else:
        subfolder = "other"
        logger.info("Routing %s → other/", filename)

    dest_key = f"tea/{fy_folder}/{subfolder}/{filename}"
    return dest_key


def _copy(raw_key: str, dest_key: str) -> None:
    """
    Server-side copy from RAW_BUCKET to BRONZE_BUCKET.
    Data never passes through Lambda memory.
    """
    s3.copy_object(
        CopySource={"Bucket": RAW_BUCKET, "Key": raw_key},
        Bucket=BRONZE_BUCKET,
        Key=dest_key,
    )
    logger.info("Copied s3://%s/%s → s3://%s/%s", RAW_BUCKET, raw_key, BRONZE_BUCKET, dest_key)


def _bronze_key_exists(bronze_key: str) -> bool:
    """
    Return True if the key already exists in BRONZE_BUCKET.
    Uses head_object which is a lightweight metadata-only call.
    """
    try:
        s3.head_object(Bucket=BRONZE_BUCKET, Key=bronze_key)
        return True
    except ClientError as exc:
        if exc.response["Error"]["Code"] in ("404", "NoSuchKey"):
            return False
        raise


# ---------------------------------------------------------------------------
# S3 event mode
# ---------------------------------------------------------------------------

def _handle_s3_event(event: dict) -> None:
    """
    Process an S3 event notification.  Each record contains one newly
    created object under raw/tea/.  Re-raises on any error so Lambda
    marks the invocation as failed and S3 can retry.
    """
    for record in event["Records"]:
        raw_key = urllib.parse.unquote_plus(record["s3"]["object"]["key"])
        logger.info("S3 event: processing key %s", raw_key)

        try:
            dest_key = _destination_key(raw_key)
            _copy(raw_key, dest_key)
        except Exception:
            logger.exception("Failed to route s3://%s/%s", RAW_BUCKET, raw_key)
            raise  # Re-raise so Lambda marks invocation failed → S3 retries


# ---------------------------------------------------------------------------
# Backfill mode
# ---------------------------------------------------------------------------

def _handle_backfill() -> dict:
    """
    List all objects under raw/tea/, skip those already present in bronze,
    and copy the rest.  Errors per file are caught, logged, and counted so
    a single bad file does not abort the entire backfill.

    Returns a stats dict: {"processed": int, "skipped": int, "failed": int}
    """
    stats = {"processed": 0, "skipped": 0, "failed": 0}

    paginator = s3.get_paginator("list_objects_v2")
    pages = paginator.paginate(Bucket=RAW_BUCKET, Prefix="tea/")

    for page in pages:
        for obj in page.get("Contents", []):
            raw_key = obj["Key"]

            # Skip "directory" placeholder keys (end with /)
            if raw_key.endswith("/"):
                continue

            # Skip keys that don't have a meaningful FY folder + filename.
            parts = raw_key.split("/")
            if len(parts) < 3:
                logger.warning("Skipping malformed key: %s", raw_key)
                stats["skipped"] += 1
                continue

            try:
                dest_key = _destination_key(raw_key)

                if _bronze_key_exists(dest_key):
                    logger.info("Skipping already-present key: s3://%s/%s", BRONZE_BUCKET, dest_key)
                    stats["skipped"] += 1
                    continue

                _copy(raw_key, dest_key)
                stats["processed"] += 1

            except Exception:
                logger.exception("Backfill: failed to process %s", raw_key)
                stats["failed"] += 1

    logger.info("Backfill complete: %s", stats)
    return stats


# ---------------------------------------------------------------------------
# Lambda entry point
# ---------------------------------------------------------------------------

def lambda_handler(event: dict, context) -> dict:  # noqa: ANN001
    """
    Lambda entry point.

    S3 event mode  — triggered automatically when objects land in raw/tea/.
    Backfill mode  — invoke manually with payload {"backfill": true}.
    """
    if event.get("backfill") is True:
        logger.info("Running in backfill mode")
        return _handle_backfill()

    if "Records" in event:
        logger.info("Running in S3 event mode (%d record(s))", len(event["Records"]))
        _handle_s3_event(event)
        return {"status": "ok"}

    logger.warning("Unrecognised event shape; nothing to do. event keys: %s", list(event.keys()))
    return {"status": "noop"}

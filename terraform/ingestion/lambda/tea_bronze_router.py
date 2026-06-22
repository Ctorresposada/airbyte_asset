"""
tea_bronze_router.py — Lambda that routes files from raw/tea/ to bronze/tea/<subfolder>/.

Routing rules (evaluated in order):
  1. .pdf extension           → bronze/tea/pdfs/<fy_prefix>_<filename>              (copied as-is)
  2. .csv with > 1200 columns → bronze/tea/wide_tables/<fy_prefix>_<filename>       (copied as-is)
  3. .csv with ≤ 1200 columns → bronze/tea/<fy_prefix>_<table_name>/<stem>.parquet  (converted)
  4. anything else            → bronze/tea/other/<fy_prefix>_<filename>              (copied as-is)

FY prefix derivation:
  The raw key's second path segment is the Google Drive FY folder name
  (e.g. "FY 2024-2025").  This is normalised to "2024_2025" and prepended
  to the table subfolder so each year gets its own Glue table:
    tea/2024_2025_campus_staar_grade_7/   → Glue table: tea_2024_2025_campus_staar_grade_7
    tea/2025_2026_campus_staar_grade_7/   → Glue table: tea_2025_2026_campus_staar_grade_7

  Special folders (pdfs, wide_tables, other) are flat top-level singletons;
  the FY prefix is baked into the filename so files from different years
  remain distinguishable without affecting the Glue exclusion patterns.

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

Copy strategy:
  Narrow CSVs: read into pandas (dtype=str) → write Snappy Parquet via put_object.
  All other files: s3.copy_object (server-side, same-account) — data never transits Lambda.
"""

import csv
import io
import logging
import os
import re
import urllib.parse

import boto3
import pandas as pd
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

def _normalize_fy(fy_folder: str) -> str:
    """
    Convert a Google Drive FY folder name to a clean underscore-separated prefix.

    Examples:
      "FY 2024-2025" → "2024_2025"
      "FY 2025-2026" → "2025_2026"
      "2024-2025"    → "2024_2025"
    """
    # Strip leading "FY " (case-insensitive)
    name = re.sub(r"^FY\s*", "", fy_folder, flags=re.IGNORECASE)
    # Collapse non-alphanumeric runs to underscores
    name = re.sub(r"[^a-z0-9]+", "_", name.lower())
    return name.strip("_")


def _derive_table_name(filename_no_ext: str) -> str:
    """
    Convert a filename stem to a clean Glue-compatible table name segment.

    Steps:
      1. Remove a leading 4-digit year followed by optional spaces or dashes.
      2. Lowercase the result.
      3. Replace runs of non-alphanumeric characters with a single underscore.
      4. Strip leading/trailing underscores.

    Examples:
      "2025 Campus STAAR Grade 3"                            → "campus_staar_grade_3"
      "2025-additional-targeted-support"                     → "additional_targeted_support"
      "multi-year-unacceptable-list-2025-after-2025-appeal"  → "multi_year_unacceptable_list_2025_after_2025_appeal"
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
    parts[1] = FY folder (e.g. "FY 2024-2025")
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

    Flat bronze layout — FY year baked into the folder or filename so each
    year's data lives in its own Glue table and never merges across years:

      Regular CSV  → tea/<fy_prefix>_<table_name>/<filename>
                     e.g. tea/2024_2025_campus_staar_grade_7/2025 Campus STAAR Grade 7.csv
                          → Glue table: tea_2024_2025_campus_staar_grade_7

      Wide CSV     → tea/wide_tables/<fy_prefix>_<filename>   (excluded from crawler)
      PDF          → tea/pdfs/<fy_prefix>_<filename>          (excluded from crawler)
      Other        → tea/other/<fy_prefix>_<filename>         (excluded from crawler)
    """
    fy_folder, filename = _parse_raw_key(raw_key)
    fy_prefix = _normalize_fy(fy_folder)
    name, _, ext = filename.rpartition(".")
    ext_lower = ext.lower() if ext else ""

    if ext_lower == "pdf":
        dest_key = f"tea/pdfs/{fy_prefix}_{filename}"
        logger.info("Routing %s → pdfs/ (pdf)", filename)
    elif ext_lower == "csv":
        col_count = _count_csv_columns(RAW_BUCKET, raw_key)
        logger.info("CSV %s has %d columns", filename, col_count)
        if col_count > WIDE_COLUMN_THRESHOLD:
            dest_key = f"tea/wide_tables/{fy_prefix}_{filename}"
            logger.info("Routing %s → wide_tables/ (%d cols)", filename, col_count)
        else:
            table_name = _derive_table_name(name)
            dest_key = f"tea/{fy_prefix}_{table_name}/{name}.parquet"
            logger.info("Routing %s → %s_%s/ (parquet)", filename, fy_prefix, table_name)
    else:
        dest_key = f"tea/other/{fy_prefix}_{filename}"
        logger.info("Routing %s → other/ (unknown ext)", filename)

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


def _convert_to_parquet(raw_key: str, dest_key: str) -> None:
    """
    Read a CSV from RAW_BUCKET into pandas (all columns as string to prevent
    type-inference issues in Glue/Athena), convert to Snappy Parquet, and
    write to BRONZE_BUCKET.  The Parquet schema embeds string types so the
    Glue crawler reads them directly without needing a post-crawl enforcer.

    Uses a temp-key pattern (.tmp suffix) so the final key only appears once
    the full Parquet file has been committed to S3.
    """
    response = s3.get_object(Bucket=RAW_BUCKET, Key=raw_key)
    df = pd.read_csv(response["Body"], dtype=str, keep_default_na=False)
    # Glue/Athena reject column names with control characters. TEA source
    # sheets sometimes have wrapped cells that export with embedded newlines,
    # tabs, or null bytes. Replace them with a space, collapse consecutive
    # spaces to a single underscore, lowercase, then strip.
    df.columns = (
        df.columns
        .str.replace(r"[\n\r\t\x00]", " ", regex=True)
        .str.strip()
    )
    buf = io.BytesIO()
    df.to_parquet(buf, engine="pyarrow", compression="snappy", index=False)

    # Atomic write: put to a .tmp key first, then copy to the final key.
    # The final key only appears once the data is fully committed.
    tmp_key = dest_key + ".tmp"
    parquet_bytes = buf.getvalue()
    s3.put_object(Bucket=BRONZE_BUCKET, Key=tmp_key, Body=parquet_bytes)
    s3.copy_object(
        CopySource={"Bucket": BRONZE_BUCKET, "Key": tmp_key},
        Bucket=BRONZE_BUCKET,
        Key=dest_key,
    )
    s3.delete_object(Bucket=BRONZE_BUCKET, Key=tmp_key)

    logger.info(
        "Converted s3://%s/%s → s3://%s/%s (%d rows, %d cols)",
        RAW_BUCKET, raw_key, BRONZE_BUCKET, dest_key, len(df), len(df.columns),
    )


def _transfer(raw_key: str, dest_key: str) -> None:
    """Route to parquet conversion for narrow CSVs, server-side copy for everything else."""
    if dest_key.endswith(".parquet"):
        _convert_to_parquet(raw_key, dest_key)
    else:
        _copy(raw_key, dest_key)


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
            _transfer(raw_key, dest_key)
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

                _transfer(raw_key, dest_key)
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

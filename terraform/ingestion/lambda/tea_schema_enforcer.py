"""
tea_schema_enforcer.py — Lambda that enforces all-string column types on every
tea_* table in the bronze Glue database after the TEA crawler succeeds.

Why this exists:
  The Glue crawler infers column types from CSV data. Empty strings in numeric
  columns cause Athena to throw NumberFormatException when querying. Setting
  all columns to string prevents this; proper type casting is handled
  downstream in dbt silver models.

Trigger:
  EventBridge rule on Glue Crawler State Change event for the TEA crawler
  with state == "Succeeded". Runs automatically after every scheduled or
  manual crawler execution.

Manual invocation:
  aws lambda invoke \
    --function-name region-20-<env>-tea-schema-enforcer \
    --payload '{}' \
    --cli-binary-format raw-in-base64-out \
    response.json && cat response.json

Environment variables:
  GLUE_DATABASE  — name of the bronze Glue database (e.g. escr20_bronze_dev)
  TABLE_PREFIX   — prefix used to filter TEA tables (e.g. tea_)
"""

import logging
import os

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

glue = boto3.client("glue")

GLUE_DATABASE = os.environ["GLUE_DATABASE"]
TABLE_PREFIX = os.environ["TABLE_PREFIX"]


def _get_tea_tables() -> list[dict]:
    """Return all Glue tables whose name starts with TABLE_PREFIX."""
    paginator = glue.get_paginator("get_tables")
    tables = []
    for page in paginator.paginate(DatabaseName=GLUE_DATABASE):
        tables += [t for t in page["TableList"] if t["Name"].startswith(TABLE_PREFIX)]
    return tables


def _all_string(table: dict) -> bool:
    """Return True if every column in the table is already typed as string."""
    cols = table.get("StorageDescriptor", {}).get("Columns", [])
    return all(c.get("Type", "") == "string" for c in cols)


def _enforce_string_columns(table: dict) -> dict:
    """
    Return a copy of the table with every column type set to 'string'.
    Partition keys are left unchanged — they are usually typed correctly
    and modifying them can break partition pruning.
    """
    sd = dict(table["StorageDescriptor"])
    sd["Columns"] = [
        {**col, "Type": "string"} for col in sd.get("Columns", [])
    ]

    table_input = {
        "Name": table["Name"],
        "StorageDescriptor": sd,
        "Parameters": table.get("Parameters", {}),
    }
    if "PartitionKeys" in table:
        table_input["PartitionKeys"] = table["PartitionKeys"]
    if "TableType" in table:
        table_input["TableType"] = table["TableType"]
    if "Description" in table:
        table_input["Description"] = table["Description"]

    return table_input


def _enforce_all_tables() -> dict:
    """
    Iterate over all tea_* tables, set every column to string where needed.
    Returns stats dict: {updated, skipped, failed}.
    """
    stats = {"updated": 0, "skipped": 0, "failed": 0}
    tables = _get_tea_tables()
    logger.info("Found %d tables with prefix '%s'", len(tables), TABLE_PREFIX)

    for table in tables:
        name = table["Name"]
        try:
            if _all_string(table):
                logger.info("Skipping %s — all columns already string", name)
                stats["skipped"] += 1
                continue

            table_input = _enforce_string_columns(table)
            glue.update_table(DatabaseName=GLUE_DATABASE, TableInput=table_input)
            logger.info("Updated %s — all columns set to string", name)
            stats["updated"] += 1

        except Exception:
            logger.exception("Failed to update table %s", name)
            stats["failed"] += 1

    logger.info("Schema enforcement complete: %s", stats)
    return stats


def lambda_handler(event: dict, context) -> dict:  # noqa: ANN001
    """
    Entry point. Handles both EventBridge Glue crawler events and direct
    manual invocations (any payload shape).
    """
    crawler_name = event.get("detail", {}).get("crawlerName", "manual")
    logger.info("Triggered by crawler: %s", crawler_name)

    stats = _enforce_all_tables()
    return {"statusCode": 200, "body": stats}

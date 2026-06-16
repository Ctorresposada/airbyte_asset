"""
PDF Table → S3 Bronze / Glue Catalog
Triggered by S3 ObjectCreated events on the raw bucket for .pdf files.
Extracts all tables from the PDF (multi-page aware), writes Snappy Parquet
to the bronze bucket partitioned by fiscal_year, and registers/updates the
Glue catalog table so Athena can query across all years automatically.

S3 key convention expected:
    tea/<fiscal_year_folder>/<filename>.pdf
    e.g. tea/FY 2024-2025/Campus Summary.pdf

Output layout in bronze:
    pdf-extracted/<table_name>/fiscal_year=<fy>/<table_name>.parquet
    e.g. pdf-extracted/campus_summary/fiscal_year=fy_2024_2025/campus_summary.parquet

Lambda env vars:
    BRONZE_BUCKET : target S3 bucket for Parquet output
    GLUE_DATABASE : Glue catalog database name for the bronze layer
"""

import io
import os
import re
import urllib.parse

import logging

import boto3
import pandas as pd
import pdfplumber
import pyarrow as pa
import pyarrow.parquet as pq

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client("s3")
glue = boto3.client("glue")


def _slugify(text):
    """Convert arbitrary text to a lowercase snake_case Glue/Athena identifier.
    Leading digit segments (e.g. a year) are moved to the end so the name is
    always valid without quoting in Athena SQL.
      2025_aea_campus_final  →  aea_campus_final_2025
    """
    slug = re.sub(r"_+", "_", re.sub(r"[^a-z0-9]+", "_", text.lower())).strip("_")
    match = re.match(r"^(\d+)_(.+)$", slug)
    if match:
        slug = f"{match.group(2)}_{match.group(1)}"
    return slug


def _stem(filename):
    """Strip all trailing .pdf extensions (handles double-extension like name.pdf.pdf)."""
    name = filename
    while name.lower().endswith(".pdf"):
        name = name[:-4]
    return name


def _strip_year(stem):
    """Remove 4-digit year tokens from a filename stem so table names stay stable across years.

    peg-list-2025-final  →  peg-list-final
    2025-aea-campus      →  aea-campus
    """
    result = re.sub(r"[-_\s]?\b\d{4}\b[-_\s]?", "-", stem)
    return result.strip("-_")


def _reconcile_headers(headers, rows):
    """Fix two common PDF table extraction issues before building the DataFrame.

    1. Multi-row headers — some PDFs split column headers across two rows
       (e.g. row 0 has 'District Name' and row 1 has 'AEA Campus Type' for the
       last column). Detected when the first data row contains no long numbers
       (≥ 6 digits), which would indicate real data. The two rows are merged and
       data starts from row 2.

    2. Column shift — a header can be positioned one column to the left of its
       actual data column (common when the PDF has a blank leading counter column).
       Detected when a named header has all-empty data while the adjacent column
       has data but no header; the header is shifted right to align.

    Returns adjusted (headers, rows).
    """
    if not rows:
        return headers, rows

    def _looks_like_header_row(row):
        has_text = False
        for val in row:
            s = str(val).strip() if val is not None else ""
            if not s:
                continue
            if re.search(r"\d{5,}", s):
                return False  # campus/district number → real data
            has_text = True
        return has_text

    # Step 1: merge second header row
    second_header = None
    if _looks_like_header_row(rows[0]):
        second_header = rows[0]
        merged = list(headers)
        for i, val in enumerate(second_header):
            if i < len(merged) and val and str(val).strip():
                if not merged[i] or not str(merged[i]).strip():
                    merged[i] = val
        headers = merged
        rows = rows[1:]

    # Remove repeated second header rows on subsequent pages
    if second_header is not None:
        rows = [row for row in rows if row != second_header]

    if not rows:
        return headers, rows

    # Step 2: shift misaligned headers
    n_cols = len(headers)
    data_populated = [False] * n_cols
    for row in rows:
        for i, val in enumerate(row):
            if i < n_cols and val is not None and str(val).strip():
                data_populated[i] = True

    new_headers = list(headers)
    for i in range(n_cols):
        hdr = new_headers[i]
        if hdr and str(hdr).strip() and not data_populated[i]:
            for j in range(i + 1, min(i + 3, n_cols)):
                if data_populated[j] and (not new_headers[j] or not str(new_headers[j]).strip()):
                    new_headers[j] = hdr
                    new_headers[i] = None
                    break

    return new_headers, rows


def _extract_file_date(stem):
    """Extract the first date-like pattern found anywhere in a filename stem.

    Tries in order of specificity so the most precise match wins:
      YYYY-MM-DD  →  "2025-06-15"
      YYYY-MM     →  "2025-06"
      YYYY        →  "2025"

    Works whether the year is a prefix, suffix, or embedded:
      2025-campus-pairings  →  "2025"
      peg-list-2025-final   →  "2025"

    Returns None if no date pattern is found.
    """
    if m := re.search(r"\b(\d{4}-\d{2}-\d{2})\b", stem):
        return m.group(1)
    if m := re.search(r"\b(\d{4}-\d{2})\b", stem):
        return m.group(1)
    if m := re.search(r"\b(\d{4})\b", stem):
        return m.group(1)
    return None


def handler(event, context):
    raise RuntimeError("TEST ALARM — remove this line after confirming the CloudWatch alarm fires")
    bucket = event["Records"][0]["s3"]["bucket"]["name"]
    key = urllib.parse.unquote_plus(event["Records"][0]["s3"]["object"]["key"])

    # 1. Read PDF from S3
    response = s3.get_object(Bucket=bucket, Key=key)
    pdf_bytes = response["Body"].read()

    # 2. Extract table rows across all pages
    rows = []
    headers = None
    with pdfplumber.open(io.BytesIO(pdf_bytes)) as pdf:
        for page in pdf.pages:
            table = page.extract_table()
            if not table:
                continue
            if headers is None:
                headers = table[0]
                rows.extend(table[1:])
            else:
                rows.extend(table[1:])  # skip repeated header rows on subsequent pages

    if not headers:
        raise ValueError(f"No extractable table found in PDF: s3://{bucket}/{key}")

    headers, rows = _reconcile_headers(headers, rows)
    logger.info("Reconciled headers: %s", headers)
    logger.info("Sample rows (first 3): %s", rows[:3])

    # 3. Derive names from the S3 key
    #    key structure: tea/<fiscal_year_folder>/<filename>.pdf
    #    e.g.          tea/FY 2024-2025/Campus Summary.pdf
    parts = key.split("/")
    filename = parts[-1]
    # Use the immediate parent folder as the fiscal year partition.
    # Falls back to "unknown" if the PDF sits directly under tea/ with no subfolder.
    raw_fy = parts[-2] if len(parts) >= 3 else "unknown"

    table_name = _slugify(_strip_year(_stem(filename)))
    fiscal_year = _slugify(raw_fy)
    file_date = _extract_file_date(_stem(filename))

    # 4. Build DataFrame with audit columns
    # Column order: table data | file info | fiscal_year | ingestion metadata
    # Slugify headers so Parquet column names match the Glue catalog exactly.
    # Raw headers like 'District Name' and 'Campus\nNumber' become 'district_name', 'campus_number'.
    slugified_headers = [_slugify(h) if h else f"col_{i}" for i, h in enumerate(headers)]
    df = pd.DataFrame(rows, columns=slugified_headers)

    # Drop placeholder columns (col_0, col_1, ...) that have no meaningful data.
    # These arise from blank or undetected header cells in complex PDF table layouts.
    empty_placeholders = [
        col for col in df.columns
        if re.match(r"^col_\d+$", col) and df[col].replace("", pd.NA).isna().all()
    ]
    if empty_placeholders:
        df = df.drop(columns=empty_placeholders)
        logger.info("Dropped empty placeholder columns: %s", empty_placeholders)

    # Drop footer/summary rows that have no campus_number (e.g. "Total Campuses = 317")
    if "campus_number" in df.columns:
        before = len(df)
        df = df[df["campus_number"].notna() & (df["campus_number"].str.strip() != "")]
        dropped = before - len(df)
        if dropped:
            logger.info("Dropped %d non-data row(s) with null campus_number", dropped)

    df["file_name"] = filename
    df["file_date"] = file_date
    df["fiscal_year"] = fiscal_year
    df["source_file_path"] = f"s3://{bucket}/{key}"
    df["ingested_at"] = pd.Timestamp.now(tz="UTC").strftime("%Y-%m-%d %H:%M:%S")

    # Hive-style partition keeps each year isolated — no overwrite between years.
    output_prefix = f"pdf-extracted/{table_name}/fiscal_year={fiscal_year}/"
    output_key = f"{output_prefix}{table_name}.parquet"

    # 5. Write Snappy Parquet to bronze bucket
    buf = io.BytesIO()
    pq.write_table(pa.Table.from_pandas(df), buf, compression="snappy")
    s3.put_object(
        Bucket=os.environ["BRONZE_BUCKET"],
        Key=output_key,
        Body=buf.getvalue(),
    )
    logger.info("Written: s3://%s/%s  (%d rows)", os.environ["BRONZE_BUCKET"], output_key, len(df))

    # 6. Register / update Glue table and partition
    #    fiscal_year is a partition key — exclude it from StorageDescriptor columns.
    #    All columns typed as string — dbt Silver handles casting.
    columns = [
        {"Name": _slugify(col), "Type": "string"}
        for col in df.columns
        if col != "fiscal_year"
    ]
    partition_keys = [{"Name": "fiscal_year", "Type": "string"}]
    table_root = f"s3://{os.environ['BRONZE_BUCKET']}/pdf-extracted/{table_name}/"
    partition_location = f"{table_root}fiscal_year={fiscal_year}/"

    _upsert_glue_table(
        database=os.environ["GLUE_DATABASE"],
        table=table_name,
        location=table_root,
        columns=columns,
        partition_keys=partition_keys,
    )
    _upsert_partition(
        database=os.environ["GLUE_DATABASE"],
        table=table_name,
        partition_values=[fiscal_year],
        location=partition_location,
        columns=columns,
    )

    logger.info(
        "PDF successfully extracted and loaded into Glue table.\n"
        "  File        : %s\n"
        "  Rows        : %d\n"
        "  Table       : %s.%s\n"
        "  Partition   : fiscal_year=%s\n"
        "  S3 output   : s3://%s/%s",
        filename, len(df), os.environ["GLUE_DATABASE"], table_name,
        fiscal_year, os.environ["BRONZE_BUCKET"], output_key,
    )

    return {"statusCode": 200, "body": f"Processed {len(df)} rows from {filename} (fiscal_year={fiscal_year})"}

# Register the data into a table in Glue Catalog
def _upsert_glue_table(database, table, location, columns, partition_keys):
    table_input = {
        "Name": table,
        "StorageDescriptor": {
            "Columns": columns,
            "Location": location,
            "InputFormat": "org.apache.hadoop.mapred.TextInputFormat",
            "OutputFormat": "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat",
            "SerdeInfo": {
                "SerializationLibrary": "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe",
                "Parameters": {"serialization.format": "1"},
            },
            "Compressed": True,
        },
        "PartitionKeys": partition_keys,
        "TableType": "EXTERNAL_TABLE",
        "Parameters": {
            "classification": "parquet",
            "compressionType": "snappy",
            "typeOfData": "file",
        },
    }
    try:
        glue.update_table(DatabaseName=database, TableInput=table_input)
        logger.info("Updated Glue table: %s.%s", database, table)
    except glue.exceptions.EntityNotFoundException:
        glue.create_table(DatabaseName=database, TableInput=table_input)
        logger.info("Created Glue table: %s.%s", database, table)


def _upsert_partition(database, table, partition_values, location, columns):
    partition_input = {
        "Values": partition_values,
        "StorageDescriptor": {
            "Columns": columns,
            "Location": location,
            "InputFormat": "org.apache.hadoop.mapred.TextInputFormat",
            "OutputFormat": "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat",
            "SerdeInfo": {
                "SerializationLibrary": "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe",
                "Parameters": {"serialization.format": "1"},
            },
            "Compressed": True,
        },
    }
    try:
        glue.create_partition(DatabaseName=database, TableName=table, PartitionInput=partition_input)
        logger.info("Created partition %s on %s.%s", partition_values, database, table)
    except glue.exceptions.AlreadyExistsException:
        glue.update_partition(
            DatabaseName=database,
            TableName=table,
            PartitionValueList=partition_values,
            PartitionInput=partition_input,
        )
        logger.info("Updated partition %s on %s.%s", partition_values, database, table)

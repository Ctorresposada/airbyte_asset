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

import boto3
import pandas as pd
import pdfplumber
import pyarrow as pa
import pyarrow.parquet as pq

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


def handler(event, context):
    bucket = event["Records"][0]["s3"]["bucket"]["name"]
    key = event["Records"][0]["s3"]["object"]["key"]

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

    # 3. Build DataFrame with audit columns
    df = pd.DataFrame(rows, columns=headers)
    df["source_file_path"] = f"s3://{bucket}/{key}"
    df["ingested_at"] = pd.Timestamp.now().isoformat()

    # 4. Derive names from the S3 key
    #    key structure: tea/<fiscal_year_folder>/<filename>.pdf
    #    e.g.          tea/FY 2024-2025/Campus Summary.pdf
    parts = key.split("/")
    filename = parts[-1]
    # Use the immediate parent folder as the fiscal year partition.
    # Falls back to "unknown" if the PDF sits directly under tea/ with no subfolder.
    raw_fy = parts[-2] if len(parts) >= 3 else "unknown"

    table_name = _slugify(_stem(filename))
    fiscal_year = _slugify(raw_fy)

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
    print(f"Written: s3://{os.environ['BRONZE_BUCKET']}/{output_key}  ({len(df)} rows)")

    # 6. Register / update Glue table
    #    Location points to the table root so Athena picks up all fiscal_year partitions.
    #    All columns typed as string — dbt Silver handles casting.
    columns = [
        {"Name": _slugify(col), "Type": "string"}
        for col in df.columns
    ]
    partition_keys = [{"Name": "fiscal_year", "Type": "string"}]
    table_root = f"s3://{os.environ['BRONZE_BUCKET']}/pdf-extracted/{table_name}/"

    _upsert_glue_table(
        database=os.environ["GLUE_DATABASE"],
        table=table_name,
        location=table_root,
        columns=columns,
        partition_keys=partition_keys,
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
        print(f"Updated Glue table: {database}.{table}")
    except glue.exceptions.EntityNotFoundException:
        glue.create_table(DatabaseName=database, TableInput=table_input)
        print(f"Created Glue table: {database}.{table}")

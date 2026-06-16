# R2EP2IC-33 — S3 Data Lake: Folder Structure, Naming Convention & Partitioning Strategy
# Variant: Airbyte OSS + dbt Core (self-hosted on EC2)

> Back to [docs landing page](README.md) · See also the [Concepts Glossary](concepts-glossary.md)

> **In plain terms**
>
> A "data lake" is just a very large, organized set of folders in cloud storage (AWS **S3**) where all the platform's data files live. This document defines the rules for *where* each file goes, *what* it is named, and *how* it is grouped — so that every tool writing data and every analyst reading it agree on the same layout. Getting this right matters because consistent folder structure is what lets queries stay fast and cheap, keeps sensitive data out of the wrong place, and means no one has to guess where a given dataset lives. This is the **OSS (self-hosted)** version of the design, where Region 20 runs the ingestion and transformation tools itself on its own AWS servers.

> **Which variant is this? (OSS vs Cloud)**
>
> There are two versions of this design document, and they describe the *same* folder layout but a *different* way of running the tools that produce the data:
>
> - **This document (OSS / self-hosted):** Region 20 runs the *free, open-source editions* of both tools — **Airbyte OSS** and **dbt Core** — on its own AWS **EC2** virtual servers. "OSS" means open-source software. More control and no subscription fee, but Region 20 is responsible for patching, upgrading, and keeping those servers healthy.
> - **The other document ([`s3-data-lake-structure-cloud.md`](s3-data-lake-structure-cloud.md), "Cloud"):** the same tools run *by their vendors* as paid online services (Airbyte Cloud and dbt Cloud), with no servers for Region 20 to operate.
>
> The decision between them is still open (see [Section 10](#10-open-decisions)). The folder structure, bucket names, and partitioning rules are intentionally identical across both so the choice can be made — or changed — without re-laying-out the data lake.

> **The "Bronze / Silver / Gold" layers (the medallion model):** the platform refines data in stages, the way raw ore is purified into finished metal. **Bronze** is data freshly ingested from source systems (cleaned only enough to store reliably); **Silver** is data that has been reshaped and joined into structured, analysis-ready tables; **Gold** is the final report-ready output. Each layer lives in its own separate S3 bucket so access can be controlled independently and a problem in one stage cannot corrupt another. In this platform, Gold lives in the **Redshift** data warehouse rather than in S3, so there is no "gold bucket." (See the [Concepts Glossary](concepts-glossary.md) for the medallion model and Redshift.)

> **What "partitioning" means:** partitioning is splitting a large table's files into folders by a column value — most often a date — so a query that only needs recent data can skip everything else. For example, if files are grouped into one folder per day, a query for "yesterday" reads a single day's folder instead of scanning years of history. Since the query engine (**Athena**) bills by the amount of data it reads, good partitioning makes queries both faster and cheaper. [Section 6](#6-partitioning-strategy) defines the exact partitioning rules.

## 1. Guiding Principles

> **Two terms used heavily below.** The **Glue Catalog** (AWS Glue Data Catalog) is a central index of "what tables exist and where their files live" — it lets a query engine treat folders of files as if they were database tables. **Iceberg** (Apache Iceberg) is an open table format that adds database-like features (reliable updates, schema changes, time-travel snapshots) on top of plain files in S3. Both are defined in the [Concepts Glossary](concepts-glossary.md).

1. **Uniformity first** — all data writers (Airbyte OSS, manual uploads) follow the same prefix schema so the Glue Catalog requires zero custom config per table.
2. **Partition pruning** — partition keys match the most common query filters (date range + source) to minimize S3 scan costs.
3. **Layer isolation** — each medallion layer (bronze → silver) lives in its own bucket; cross-layer access is IAM-controlled, not path-based.
4. **Immutability at bronze** — raw Iceberg files are never modified after landing. Airbyte only appends new data files.
5. **FERPA compliance** — no HR-schema data from Oracle APEX is ever written; enforced by Airbyte stream selection and documented here. (FERPA is the U.S. federal law protecting the privacy of student education records.)

---

## 2. S3 Bucket Naming Convention

Pattern: `r20-{env}-{layer}-{account_id}`

| Layer          | Bucket Name                             | Purpose                                 |
|----------------|-----------------------------------------|-----------------------------------------|
| Bronze         | `r20-{env}-bronze-{account_id}`         | Raw ingestion from all sources          |
| Silver         | `r20-{env}-silver-{account_id}`         | dbt-Athena Iceberg tables               |
| Athena Results | `r20-{env}-athena-results-{account_id}` | Temporary query results (7-day TTL)     |

- `{env}` → `prod` · `stg` · `dev`
- `{account_id}` → full 12-digit AWS account number (ensures global uniqueness without random suffixes)
- Hyphen-only, lowercase, no underscores (S3 bucket name rules)
- Gold data lives in **Redshift Serverless** (not S3); no gold bucket.

**Examples (prod, account 784590287037):**
```
r20-prod-bronze-784590287037
r20-prod-silver-784590287037
r20-prod-athena-results-784590287037
```

---

## 3. Bronze Layer — Folder Structure

Bronze tables are **Iceberg format** written by Airbyte OSS (S3 Data Lake connector). Airbyte manages the Iceberg layout internally; it auto-registers tables in the Glue Catalog on first sync via Athena `CREATE TABLE ... TBLPROPERTIES ('table_type'='ICEBERG')`.

### 3.1 Iceberg Layout (Airbyte-managed)

```
s3://r20-{env}-bronze-{account_id}/
  {glue_database}/            ← Glue database name (e.g., glue_r20_bronze)
    {table_name}/             ← one prefix per source table
      data/                   ← Iceberg data files (Parquet)
      metadata/               ← snapshots, manifests, table metadata
```

- `{glue_database}` is configured once in the Airbyte S3 Data Lake connection settings.
- `{table_name}` matches the Airbyte stream name (snake_case, matches source table name).
- Airbyte handles partitioning internally — no manual Hive prefix structure needed.
- **No Glue Crawler required.** Tables are registered once via the `scripts/register_bronze_tables.sql` one-time script after the first sync.

### 3.2 Source Systems

| Source               | Airbyte Connector         | Sync Mode           | Frequency  |
|----------------------|---------------------------|---------------------|------------|
| Oracle APEX (OCI)    | Oracle CDC (LogMiner)     | Incremental CDC     | Hourly     |
| SQL Server TAS       | SQL Server CDC            | Incremental CDC     | Hourly     |
| Docebo (LMS API)     | Docebo REST               | Incremental append  | Hourly     |
| ESCWorks/Connect20   | PostgreSQL / REST         | Full refresh        | Daily      |
| Ascender ERP         | File (S3 upload)          | Full refresh        | Daily      |
| TEA Files            | File (S3 upload)          | Full refresh        | Annual     |

### 3.3 Bronze Path Example

```
# Oracle APEX — Iceberg table managed by Airbyte OSS
s3://r20-prod-bronze-784590287037/
  glue_r20_bronze/
    oracle_apex_courses/
      data/
        00000-1-abc123.parquet
        00001-2-def456.parquet
      metadata/
        v1.metadata.json
        snap-12345-1-abc.avro
```

### 3.4 HR Schema Exclusion (FERPA)

The Oracle APEX connection **must not** include any tables from the `HR` schema. Enforce via:
- Airbyte stream selection (uncheck HR schema in connection config)
- S3 bucket policy deny on `glue_r20_bronze/oracle_apex_hr_*` as defence-in-depth

---

## 4. Silver Layer — Folder Structure

Silver tables are Iceberg format, created and managed by dbt Core + dbt-athena. Iceberg manages its own internal layout; we only define the base location per model.

### 4.1 Pattern

```
s3://r20-{env}-silver-{account_id}/
  {dbt_model_name}/       ← one prefix per dbt model
    data/                 ← Iceberg data files (Parquet)
    metadata/             ← Iceberg snapshots, manifests
```

- `{dbt_model_name}` = dbt model name, e.g., `silver_courses`, `silver_students`.
- Prefix matches the Glue Catalog table location: `glue_r20_silver.{dbt_model_name}`.
- Never write directly to silver; dbt is the only writer.

### 4.2 Athena Results

```
s3://r20-{env}-athena-results-{account_id}/
  (Athena-managed files, no structure required)
```

S3 lifecycle rule: expire all objects after 7 days. Do not place application data here.

---

## 5. File Naming Convention

| Layer  | File Name Pattern                        | Who sets it          |
|--------|------------------------------------------|----------------------|
| Bronze | Iceberg-managed (`{uuid}-{seq}.parquet`) | Airbyte OSS          |
| Silver | Iceberg-managed (`{uuid}-{seq}.parquet`) | dbt Core + Athena    |
| Manual uploads (Ascender, TEA) | `{source}_{table_name}_{YYYYMMDD}[_{descriptor}].csv` | Manual convention |

Rules:
- **Lowercase + underscores** for all manually named files.
- **No spaces or special characters** except hyphens in Iceberg-managed names (Iceberg convention).
- **No version suffixes** (`_v1`, `_final`, `_new`) — use Iceberg snapshots instead.

---

## 6. Partitioning Strategy

### 6.1 Bronze — Iceberg Hidden Partitioning (Airbyte-managed)

Airbyte OSS S3 Data Lake connector applies partitioning automatically based on `_airbyte_extracted_at`. No manual Hive prefix structure.

| Source group         | Effective partition (Airbyte internal) | Notes                                          |
|----------------------|----------------------------------------|------------------------------------------------|
| All CDC sources      | `DAYS(_airbyte_extracted_at)`          | Airbyte default; configurable per connection   |
| File uploads         | `YEARS(_airbyte_extracted_at)`         | Low cardinality; no benefit from finer granularity |

### 6.2 Silver — Iceberg Hidden Partitioning (dbt-managed)

Partitioning is defined in each dbt model config. Choices depend on the table's dominant query pattern.

| Table pattern                     | Recommended partition transform | Example                                          |
|-----------------------------------|---------------------------------|--------------------------------------------------|
| Time-series / event logs          | `DAYS(ingestion_date)`          | `silver_docebo_activity`, `silver_staar_scores`  |
| Master data (students, districts) | `bucket(CDN, 16)`               | `silver_students`, `silver_districts`            |
| Slowly-changing dims              | No partitioning (small tables)  | `silver_docebo_courses`                          |

CDN (County District Number) is the universal join key — bucket partitioning on CDN benefits star-schema joins.

dbt model config example:
```sql
{{ config(
    materialized         = 'incremental',
    incremental_strategy = 'merge',
    unique_key           = 'student_id',
    table_type           = 'iceberg',
    partitioned_by       = ["days(ingestion_date)"]
) }}
```

---

## 7. Infrastructure & Orchestration

| Component        | Technology                    | Hosting        |
|------------------|-------------------------------|----------------|
| Ingestion        | Airbyte OSS                   | EC2 (self-hosted) |
| Transformation   | dbt Core + dbt-athena         | EC2 (self-hosted) |
| Orchestration    | AWS Step Functions            | Managed (AWS)  |
| Airbyte trigger  | Lambda (OAuth2 client creds)  | Managed (AWS)  |
| dbt trigger      | SSM Run Command               | Managed (AWS)  |
| Query engine     | Amazon Athena                 | Managed (AWS)  |
| Gold store       | Amazon Redshift Serverless    | Managed (AWS)  |

**Pipeline flow:**
```
EventBridge Schedule
  → Step Functions
      → Lambda (trigger Airbyte sync + poll until complete)
      → SSM Run Command (dbt Core silver job on EC2)
      → SSM Run Command (dbt Core gold job on EC2)
```

---

## 8. Glue Catalog Alignment

| Glue Database   | Backed by bucket                        | Tables populated by                         |
|-----------------|-----------------------------------------|---------------------------------------------|
| `glue_r20_bronze` | `r20-{env}-bronze-{account_id}`       | Athena `CREATE TABLE` (one-time script per table) |
| `glue_r20_silver` | `r20-{env}-silver-{account_id}`       | dbt Core via dbt-athena (on each model run) |

- No Glue Crawlers. Bronze tables are registered once via `scripts/register_bronze_tables.sql` after first Airbyte sync.
- Silver catalog is managed by dbt; no additional registration needed.
- External schema `r20_bronze` in Redshift Serverless maps to `glue_r20_bronze` via Spectrum for ad-hoc queries.

---

## 9. Summary: Path Quick Reference

```
Bronze (Iceberg, Airbyte OSS):
  s3://r20-prod-bronze-784590287037/glue_r20_bronze/{table_name}/data/...
  s3://r20-prod-bronze-784590287037/glue_r20_bronze/{table_name}/metadata/...

Silver Iceberg (dbt Core + Athena):
  s3://r20-prod-silver-784590287037/{dbt_model_name}/data/...
  s3://r20-prod-silver-784590287037/{dbt_model_name}/metadata/...

Athena query results (temp, 7-day TTL):
  s3://r20-prod-athena-results-784590287037/
```

---

## 10. Open Decisions

| Decision                       | Options                            | Impact                                                   |
|--------------------------------|------------------------------------|----------------------------------------------------------|
| Staging environment bucket     | Shared dev vs separate stg account | Naming pattern `stg` vs `dev` distinction                |
| Airbyte OSS version pinning    | Latest vs LTS                      | Connector compatibility; upgrade cadence on EC2          |
| dbt Core version               | 1.7.x vs 1.8.x                     | dbt-athena adapter compatibility                         |
| EC2 sizing (Airbyte + dbt)     | t3.medium vs m5.large              | Affects cost and sync throughput for large CDC volumes   |

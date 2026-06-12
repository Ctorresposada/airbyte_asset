# R2EP2IC-33 — S3 Data Lake: Folder Structure, Naming Convention & Partitioning Strategy
# Variant: Airbyte Cloud + dbt Cloud (fully managed SaaS)

> Back to [docs landing page](README.md) · See also the [Concepts Glossary](concepts-glossary.md)

> **In plain terms**
>
> A "data lake" is just a very large, organized set of folders in cloud storage (AWS **S3**) where all the platform's data files live. This document defines the rules for *where* each file goes, *what* it is named, and *how* it is grouped — so that every tool writing data and every analyst reading it agree on the same layout. Getting this right matters because consistent folder structure is what lets queries stay fast and cheap, keeps sensitive data out of the wrong place, and means no one has to guess where a given dataset lives. This is the **Cloud (SaaS)** version of the design, where vendors run the ingestion and transformation tools for us.

> **Which variant is this? (Cloud vs OSS)**
>
> There are two versions of this design document, and they describe the *same* folder layout but a *different* way of running the tools that produce the data:
>
> - **This document (Cloud / SaaS):** Airbyte and dbt are run *by their vendors* as paid online services — **Airbyte Cloud** (run by Airbyte, Inc.) and **dbt Cloud** (run by dbt Labs). Region 20 operates no servers for them; the tools reach into AWS to read and write the data lake. Less to operate, but a recurring subscription cost and dependence on the vendor.
> - **The other document ([`s3-data-lake-structure-oss.md`](s3-data-lake-structure-oss.md), "OSS"):** the same tools run *on Region 20's own AWS servers* (the free open-source editions). More control and no subscription, but Region 20 patches, upgrades, and babysits the servers.
>
> The decision between them is still open (see [Section 10](#10-open-decisions)). The folder structure, bucket names, and partitioning rules are intentionally identical across both so the choice can be made — or changed — without re-laying-out the data lake.

> **The "Bronze / Silver / Gold" layers (the medallion model):** the platform refines data in stages, the way raw ore is purified into finished metal. **Bronze** is data freshly ingested from source systems (cleaned only enough to store reliably); **Silver** is data that has been reshaped and joined into structured, analysis-ready tables; **Gold** is the final report-ready output. Each layer lives in its own separate S3 bucket so access can be controlled independently and a problem in one stage cannot corrupt another. In this platform, Gold lives in the **Redshift** data warehouse rather than in S3, so there is no "gold bucket." (See the [Concepts Glossary](concepts-glossary.md) for the medallion model and Redshift.)

> **What "partitioning" means:** partitioning is splitting a large table's files into folders by a column value — most often a date — so a query that only needs recent data can skip everything else. For example, if files are grouped into one folder per day, a query for "yesterday" reads a single day's folder instead of scanning years of history. Since the query engine (**Athena**) bills by the amount of data it reads, good partitioning makes queries both faster and cheaper. [Section 6](#6-partitioning-strategy) defines the exact partitioning rules.

## 1. Guiding Principles

> **Two terms used heavily below.** The **Glue Catalog** (AWS Glue Data Catalog) is a central index of "what tables exist and where their files live" — it lets a query engine treat folders of files as if they were database tables. **Iceberg** (Apache Iceberg) is an open table format that adds database-like features (reliable updates, schema changes, time-travel snapshots) on top of plain files in S3. Both are defined in the [Concepts Glossary](concepts-glossary.md).

1. **Uniformity first** — all data writers (Airbyte Cloud, manual uploads) follow the same prefix schema so the Glue Catalog requires zero custom config per table.
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
| Silver         | `r20-{env}-silver-{account_id}`         | dbt Cloud Iceberg tables via Athena     |
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

Bronze tables are **Iceberg format** written by Airbyte Cloud (S3 Data Lake destination). Airbyte manages the Iceberg layout internally; it auto-registers tables in the Glue Catalog on first sync via Athena `CREATE TABLE ... TBLPROPERTIES ('table_type'='ICEBERG')`.

### 3.1 Iceberg Layout (Airbyte Cloud-managed)

```
s3://r20-{env}-bronze-{account_id}/
  {glue_database}/            ← Glue database name (e.g., glue_r20_bronze)
    {table_name}/             ← one prefix per source table
      data/                   ← Iceberg data files (Parquet)
      metadata/               ← snapshots, manifests, table metadata
```

- `{glue_database}` is configured once in the Airbyte Cloud S3 Data Lake destination settings.
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

> **Note:** Airbyte Cloud connector availability must be confirmed for each source before finalizing this approach. OSS may have connectors not yet certified in Cloud.

### 3.3 Bronze Path Example

```
# Oracle APEX — Iceberg table managed by Airbyte Cloud
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
- Airbyte Cloud stream selection (uncheck HR schema in connection config)
- S3 bucket policy deny on `glue_r20_bronze/oracle_apex_hr_*` as defence-in-depth

---

## 4. Silver Layer — Folder Structure

Silver tables are Iceberg format, created and managed by dbt Cloud (Athena connection). Iceberg manages its own internal layout; we only define the base location per model.

### 4.1 Pattern

```
s3://r20-{env}-silver-{account_id}/
  {dbt_model_name}/       ← one prefix per dbt model
    data/                 ← Iceberg data files (Parquet)
    metadata/             ← Iceberg snapshots, manifests
```

- `{dbt_model_name}` = dbt model name, e.g., `silver_courses`, `silver_students`.
- Prefix matches the Glue Catalog table location: `glue_r20_silver.{dbt_model_name}`.
- Never write directly to silver; dbt Cloud jobs are the only writer.

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
| Bronze | Iceberg-managed (`{uuid}-{seq}.parquet`) | Airbyte Cloud        |
| Silver | Iceberg-managed (`{uuid}-{seq}.parquet`) | dbt Cloud + Athena   |
| Manual uploads (Ascender, TEA) | `{source}_{table_name}_{YYYYMMDD}[_{descriptor}].csv` | Manual convention |

Rules:
- **Lowercase + underscores** for all manually named files.
- **No spaces or special characters** except hyphens in Iceberg-managed names (Iceberg convention).
- **No version suffixes** (`_v1`, `_final`, `_new`) — use Iceberg snapshots instead.

---

## 6. Partitioning Strategy

### 6.1 Bronze — Iceberg Hidden Partitioning (Airbyte Cloud-managed)

Airbyte Cloud S3 Data Lake destination applies partitioning automatically based on `_airbyte_extracted_at`. No manual Hive prefix structure.

| Source group         | Effective partition (Airbyte internal) | Notes                                          |
|----------------------|----------------------------------------|------------------------------------------------|
| All CDC sources      | `DAYS(_airbyte_extracted_at)`          | Airbyte default; configurable per destination  |
| File uploads         | `YEARS(_airbyte_extracted_at)`         | Low cardinality; no benefit from finer granularity |

### 6.2 Silver — Iceberg Hidden Partitioning (dbt Cloud-managed)

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

| Component        | Technology                        | Hosting              |
|------------------|-----------------------------------|----------------------|
| Ingestion        | Airbyte Cloud                     | SaaS (Airbyte-managed) |
| Transformation   | dbt Cloud                         | SaaS (dbt Labs-managed) |
| Orchestration    | AWS Step Functions                | Managed (AWS)        |
| Airbyte trigger  | EventBridge HTTP Task (OAuth2)    | Managed (AWS)        |
| dbt trigger      | EventBridge HTTP Task (API token) | Managed (AWS)        |
| Query engine     | Amazon Athena                     | Managed (AWS)        |
| Gold store       | Amazon Redshift Serverless        | Managed (AWS)        |

**Pipeline flow:**
```
EventBridge Schedule
  → Step Functions
      → HTTP Task → Airbyte Cloud API (trigger sync + poll)
      → HTTP Task → dbt Cloud API (trigger silver job + poll)
      → HTTP Task → dbt Cloud API (trigger gold job + poll)
```

**Authentication:**
- Airbyte Cloud: OAuth2 client credentials (stored in Secrets Manager, retrieved by Lambda or EventBridge Connection)
- dbt Cloud: Service token with Job Runner permission (stored in Secrets Manager, injected into EventBridge Connection)

---

## 8. Glue Catalog Alignment

| Glue Database   | Backed by bucket                        | Tables populated by                                    |
|-----------------|-----------------------------------------|--------------------------------------------------------|
| `glue_r20_bronze` | `r20-{env}-bronze-{account_id}`       | Athena `CREATE TABLE` (one-time script per table)      |
| `glue_r20_silver` | `r20-{env}-silver-{account_id}`       | dbt Cloud via dbt-athena (on each model run)           |

- No Glue Crawlers. Bronze tables are registered once via `scripts/register_bronze_tables.sql` after first Airbyte sync.
- Silver catalog is managed by dbt Cloud jobs; no additional registration needed.
- External schema `r20_bronze` in Redshift Serverless maps to `glue_r20_bronze` via Spectrum for ad-hoc queries.

---

## 9. Summary: Path Quick Reference

```
Bronze (Iceberg, Airbyte Cloud):
  s3://r20-prod-bronze-784590287037/glue_r20_bronze/{table_name}/data/...
  s3://r20-prod-bronze-784590287037/glue_r20_bronze/{table_name}/metadata/...

Silver Iceberg (dbt Cloud + Athena):
  s3://r20-prod-silver-784590287037/{dbt_model_name}/data/...
  s3://r20-prod-silver-784590287037/{dbt_model_name}/metadata/...

Athena query results (temp, 7-day TTL):
  s3://r20-prod-athena-results-784590287037/
```

---

## 10. Open Decisions

| Decision                         | Options                            | Impact                                                           |
|----------------------------------|------------------------------------|------------------------------------------------------------------|
| Staging environment bucket       | Shared dev vs separate stg account | Naming pattern `stg` vs `dev` distinction                        |
| Airbyte Cloud plan               | Team vs Business tier              | Affects connector SLA, support level, and pricing per credit     |
| dbt Cloud plan                   | Team vs Enterprise                 | Affects SSO, audit logs, and job concurrency                     |
| Airbyte OSS vs Cloud (this doc)  | **Pending decision**               | See `s3-data-lake-structure-oss.md` for the OSS variant          |
| Connector availability audit     | Verify all 6 sources in Cloud      | Some OSS connectors may not be certified/available in Cloud tier |

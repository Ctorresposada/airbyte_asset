# DQ Analyses

Reusable Athena queries for bronze layer data quality inspection. These are dbt **analyses**, not models — they don't materialize. Run by compiling the SQL with dbt and pasting into Athena, or just open the file and paste the rendered version (sources are obvious).

These queries were originally executed under [R2EP2IC-67](https://caylent.atlassian.net/browse/R2EP2IC-67) to surface bronze DQ issues. Findings led to staging bug fixes in PR #139 and source-side findings reported to the client.

## Structure

| Folder | Purpose |
|--------|---------|
| `01_types/` | Column type audit (information_schema) |
| `02_volumes/` | Row counts per table for volume baselines |
| `03_domains/` | Distinct values for enum/domain columns (`status`, `active`, etc.) |
| `04_nulls/` | NULL distribution for critical columns |
| `05_uniqueness/` | Duplicate detection on candidate keys |
| `06_dates/` | Date range sanity and invalid value detection |
| `07_relationships/` | FK orphan detection (with `bigint` cast to normalize type mismatch) |

## How to run

Set env vars per [LOCAL_SETUP.md](../../../LOCAL_SETUP.md), then either:

```bash
# Render a single analysis to target/compiled/...
dbt compile --select <analysis_name>
cat target/compiled/r20_esc/analyses/dq/<path>/<file>.sql

# Or render all DQ analyses at once
dbt compile --select path:analyses/dq

# Then paste into Athena (workgroup primary)
```

Each file uses `{{ source('oracle', '<table>') }}` / `{{ source('docebo', '<table>') }}` refs, so they automatically pick up renames declared in [_oracle__sources.yml](../../models/silver/oracle/_oracle__sources.yml) / [_docebo__sources.yml](../../models/silver/docebo/_docebo__sources.yml).

## Promotion to dbt tests

When a check hardens to a contract, move it from `analyses/dq/` to `tests/dq/` and wrap the SELECT so it returns rows only when the check fails. dbt then runs it on every `dbt test` invocation. Example shape for a singular test:

```sql
-- tests/dq/<name>.sql
select 1 as failing_row
where (
    -- analysis query here, condition flipped to return rows on FAIL
    ...
) > 0
```

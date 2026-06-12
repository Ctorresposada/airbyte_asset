-- DQ analysis: row volumes for the Ascender invoice bronze table
-- Queries {{ ref('ascender_invoice') }} (not the raw source) because file_date
-- and file_name only exist as computed columns in the bronze model.
--
-- Two result sets — run separately in Athena:
--   1. Overall summary: total rows and distinct files loaded.
--   2. Per-file breakdown: rows per file, sorted newest-first.
--      Use this to spot empty files (row_count = 0 is impossible here since
--      dbt only appends non-empty scans, but a suspiciously low count like
--      1–5 rows indicates a truncated delivery).
--
-- Observed: pending first run.
-- Threshold for test promotion:
--   - Fail if total_files = 0 (table never loaded).
--   - Warn if any file delivers fewer than N rows (client to confirm
--     the expected minimum per daily delivery once baseline is known).

-- 1. Overall summary
select
    count(*)                as total_rows,
    count(distinct file_name) as total_files,
    min(file_date)          as earliest_file_date,
    max(file_date)          as latest_file_date
from {{ ref('ascender_invoice') }}
;

-- 2. Per-file breakdown
select
    file_date,
    file_name,
    count(*)                as row_count,
    min(ingested_at)        as ingested_at
from {{ ref('ascender_invoice') }}
group by file_date, file_name
order by file_date desc

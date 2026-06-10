-- DQ analysis: NULL distribution on critical contact columns
-- Observed 2026-06-10: 18144 total, 1480 null emails (8.2%), 0 null PKs,
--   4 null first_name, 3 null last_name.
-- Threshold for test promotion:
--   - contact_id: not_null (PK) — already true today, enforce.
--   - email_address: warn if null_rate exceeds an agreed threshold
--     (~10% baseline; client to confirm whether emailless contacts are
--     expected by design).

select
    count(*)                                                as total,
    sum(case when email_address is null then 1 else 0 end)  as null_emails,
    sum(case when contact_id    is null then 1 else 0 end)  as null_pks,
    sum(case when first_name    is null then 1 else 0 end)  as null_fname,
    sum(case when last_name     is null then 1 else 0 end)  as null_lname,
    round(sum(case when email_address is null then 1.0 else 0 end) * 100.0 / count(*), 2)
        as pct_null_email
from {{ source('oracle', 'contact') }}

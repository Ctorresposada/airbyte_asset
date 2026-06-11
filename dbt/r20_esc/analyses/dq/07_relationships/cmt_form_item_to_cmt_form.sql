-- DQ analysis: FK orphans cmt_form_item -> cmt_form (composite key)
-- Both sides have cmt_form_id and period_id as double in bronze; cast
-- to normalize (matches the same logic in silver staging models).
-- Observed 2026-06-10: 2073 orphans out of 5262 (39%) — material gap,
--   likely items pointing at forms that were deleted/never created.
-- Threshold for test promotion: needs client triage before deciding
--   whether this is a contract violation or expected history.

select
    count(*) as total,
    sum(case when cf.cmt_form_id is null then 1 else 0 end) as orphans
from {{ source('oracle', 'cmt_form_item') }} fi
left join {{ source('oracle', 'cmt_form') }} cf
    on cast(cast(fi.cmt_form_id as bigint) as varchar) = cast(cast(cf.cmt_form_id as bigint) as varchar)
   and cast(cast(fi.period_id   as bigint) as varchar) = cast(cast(cf.period_id   as bigint) as varchar)

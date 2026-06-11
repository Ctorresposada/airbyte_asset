-- DQ analysis: FK orphans cmt_form -> cmt_period
-- Note: bronze types diverge — cmt_form.period_id is double,
--   cmt_period.period_id is varchar. The double->bigint->varchar cast
--   normalizes both sides. Silver staging applies the same cast.
-- Observed 2026-06-10: 4 orphans out of 4173 (0.1%) — acceptable.
-- Threshold for test promotion: warn above 1%, fail above 5%
--   (final threshold subject to client review).

select
    count(*) as total,
    sum(case when p.period_id is null then 1 else 0 end) as orphans
from {{ source('oracle', 'cmt_form') }} f
left join {{ source('oracle', 'cmt_period') }} p
    on cast(cast(f.period_id as bigint) as varchar) = p.period_id

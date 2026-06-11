-- DQ analysis: FK orphans cmt_range_price_forms -> cmt_form (composite key)
-- Same cast normalization as cmt_form_item_to_cmt_form.
-- Observed 2026-06-10: 6543 orphans out of 10941 (60%) — large gap,
--   could be historical price rows for forms no longer present, or a
--   real DQ defect on the source side. Needs client confirmation.
-- Threshold for test promotion: hold until client triages — likely
--   a warn baseline rather than fail.

select
    count(*) as total,
    sum(case when cf.cmt_form_id is null then 1 else 0 end) as orphans
from {{ source('oracle', 'cmt_range_price_forms') }} rp
left join {{ source('oracle', 'cmt_form') }} cf
    on cast(cast(rp.cmt_form_id as bigint) as varchar) = cast(cast(cf.cmt_form_id as bigint) as varchar)
   and cast(cast(rp.period_id   as bigint) as varchar) = cast(cast(cf.period_id   as bigint) as varchar)

-- DQ analysis: NULL rate on price columns of cmt_range_price_forms
-- Observed 2026-06-10 (11194 total):
--   min_price:    98.1% NULL (10985)
--   max_price:    99.9% NULL (11184)
--   install_chrg: 93.8% NULL (10505)
-- Threshold for test promotion: needs client confirmation. If the high
--   NULL rate is expected (e.g. prices only set for tiered offerings),
--   leave as informational. Otherwise warn when NULL rate jumps.

select
    count(*)                                              as total,
    sum(case when min_price    is null then 1 else 0 end) as null_min_price,
    sum(case when max_price    is null then 1 else 0 end) as null_max_price,
    sum(case when install_chrg is null then 1 else 0 end) as null_install_chrg,
    round(sum(case when min_price    is null then 1.0 else 0 end) * 100.0 / count(*), 2) as pct_null_min,
    round(sum(case when max_price    is null then 1.0 else 0 end) * 100.0 / count(*), 2) as pct_null_max,
    round(sum(case when install_chrg is null then 1.0 else 0 end) * 100.0 / count(*), 2) as pct_null_install
from {{ source('oracle', 'cmt_range_price_forms') }}

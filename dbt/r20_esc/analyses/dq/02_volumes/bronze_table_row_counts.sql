-- DQ analysis: row counts per bronze table
-- Observed 2026-06-10: cmt_period=21, cmt_form=4173, cmt_form_item=5263,
--   cmt_form_item_group=660, cmt_range_price_forms=11194, contact=18144,
--   docebo_users_src=1250, docebo_courses_src=2017,
--   docebo_enrollments_src=11080.
-- Threshold for test promotion: per-table warn if drop > 20% from a
--   rolling baseline, fail if count = 0 (table empty).

select 'cmt_period'              as tbl, count(*) as n from {{ source('oracle', 'cmt_period') }}
union all select 'cmt_form',                count(*) from {{ source('oracle', 'cmt_form') }}
union all select 'cmt_form_item',           count(*) from {{ source('oracle', 'cmt_form_item') }}
union all select 'cmt_form_item_group',     count(*) from {{ source('oracle', 'cmt_form_item_group') }}
union all select 'cmt_range_price_forms',   count(*) from {{ source('oracle', 'cmt_range_price_forms') }}
union all select 'contact',                 count(*) from {{ source('oracle', 'contact') }}
union all select 'docebo_users_src',        count(*) from {{ source('docebo', 'docebo_users_src') }}
union all select 'docebo_courses_src',      count(*) from {{ source('docebo', 'docebo_courses_src') }}
union all select 'docebo_enrollments_src',  count(*) from {{ source('docebo', 'docebo_enrollments_src') }}

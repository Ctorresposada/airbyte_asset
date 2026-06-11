-- DQ analysis: distinct values of active/status enum columns across Oracle bronze
-- Observed 2026-06-10:
--   cmt_period.status: 'A' (20), empty (1)             — uses A/I, not Y/N
--   cmt_form.active:   Y (2217), N (793), empty (1162), 'Yes' (1 typo)
--   cmt_form_item_group.active: Y (86), N (4), empty (1)
--   contact.active_flag: Y (3506), N (14615), empty (23)
-- Threshold for test promotion: accepted_values per column, warn on
--   anything outside the documented enum (client must confirm full enums).

select 'cmt_period.status'         as col, status      as value, count(*) as n
  from {{ source('oracle', 'cmt_period') }}             group by status
union all select 'cmt_form.active', active, count(*)
  from {{ source('oracle', 'cmt_form') }}               group by active
union all select 'cmt_form_item_group.active', active, count(*)
  from {{ source('oracle', 'cmt_form_item_group') }}    group by active
union all select 'contact.active_flag', active_flag, count(*)
  from {{ source('oracle', 'contact') }}                group by active_flag
order by col, value

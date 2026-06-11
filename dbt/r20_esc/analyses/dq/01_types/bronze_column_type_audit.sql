-- DQ analysis: column type audit across bronze tables
-- Observed 2026-06-10: same logical ID column has different types across
--   tables (period_id is varchar in cmt_period but double in cmt_form,
--   cmt_form_item, etc.). This caused all-orphan JOINs before PR #139.
-- Threshold for test promotion: fail if any logical ID column type
--   diverges from a canonical type declared in a contract.
--
-- Note: information_schema is a metadata view that does not go through
-- dbt sources. Bronze schema and table names are hardcoded here. Keep
-- the table list in sync with the source YAMLs.

select
    table_name,
    column_name,
    data_type
from information_schema.columns
where table_schema = 'escr20_bronze_dev'
  and table_name in (
      'apex_orcl_cmt_period',
      'apex_orcl_cmt_form',
      'apex_orcl_cmt_form_item',
      'apex_orcl_cmt_form_item_group',
      'apex_orcl_cmt_range_price_forms',
      'apex_orcl_contact',
      'docebo_users_src',
      'docebo_courses_src',
      'docebo_enrollments_src'
  )
  and (
      column_name like '%_id'
      or column_name in ('status', 'active', 'active_flag', 'enrollment_status')
      or column_name like 'date_%'
      or column_name like 'effective_%'
  )
order by table_name, column_name

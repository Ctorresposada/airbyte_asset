-- TEMP: smoke-test stub — replace with full model once gold permissions are confirmed
select * from {{ source('silver', 'stg_oracle__cmt_period') }} limit 10

-- with periods as (
--     select * from {{ source('silver', 'stg_oracle__cmt_period') }}
-- )
--
-- select
--     period_id,
--     period_description,
--     start_date,
--     end_date,
--     is_active,
--     date_part('year', start_date) as period_year
-- from periods

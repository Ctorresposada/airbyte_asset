-- TEMP: smoke-test stub — replace with full model once gold permissions are confirmed
select * from {{ source('silver', 'stg_oracle__contact') }} limit 10

-- with contacts as (
--     select * from {{ source('silver', 'stg_oracle__contact') }}
-- )
--
-- select
--     contact_id,
--     first_name,
--     last_name,
--     full_name
-- from contacts

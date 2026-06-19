{{ config(materialized='table', table_type='iceberg', format='parquet') }}

-- TAS users — 1 row per user_id.
-- Source delivers 909 rows with 11 PK collisions (CDC churn).
-- Dedup by latest _airbyte_extracted_at per user_id.

with source as (
    select * from {{ source('tas', 'users') }}
),

deduped as (
    select *,
        row_number() over (
            partition by user_id
            order by _airbyte_extracted_at desc
        ) as _rn
    from source
),

renamed as (
    select
        user_id,
        employee_id,
        user_login,
        user_email,
        user_fname,
        middle_initial,
        user_lname,
        role_id,
        role_name,
        bill_rate,
        bill_rate_name,
        division_code_id,
        active_flag,
        active_date,
        inactive_date
    from deduped
    where _rn = 1
)

select * from renamed

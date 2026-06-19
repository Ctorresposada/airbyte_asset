{{ config(materialized='table', table_type='iceberg', format='parquet') }}

-- TAS timesheets — 1 row per time_log_id (fact table).
-- Source delivers 1,248,816 rows with 177,276 PK collisions (Airbyte CDC churn).
-- Dedup by latest _airbyte_extracted_at per time_log_id.

with source as (
    select * from {{ source('tas', 'timesheet') }}
),

deduped as (
    select *,
        row_number() over (
            partition by time_log_id
            order by _airbyte_extracted_at desc
        ) as _rn
    from source
),

renamed as (
    select
        time_log_id,
        time_log_date,
        status_date,
        client_id,
        client_name,
        campus_id,
        campus_code,
        campus_name,
        program_id,
        activity_code,
        contact_type_id,
        contact_type,
        contact_type_name,
        time_log_type_id,
        hours,
        remarks,
        county_client_code
    from deduped
    where _rn = 1
)

select * from renamed

{{ config(materialized='table', table_type='iceberg', format='parquet') }}

with source as (
    select * from {{ source('docebo', 'docebo_enrollments_src') }}
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
        cast(cast(user_id as bigint) as varchar)                    as user_id,
        enrollment_status,
        cast(substr(enrollment_completion_date, 1, 10) as date)     as completion_date
    from deduped
    where _rn = 1
    and enrollment_status = 'completed'
    and enrollment_completion_date is not null
)

select * from renamed

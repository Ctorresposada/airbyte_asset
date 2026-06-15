{{ config(materialized='table', table_type='iceberg', format='parquet') }}

with source as (
    select * from {{ source('oracle', 'cmt_period') }}
),

deduped as (
    select *,
        row_number() over (
            partition by period_id
            order by _airbyte_extracted_at desc
        ) as _rn
    from source
),

renamed as (
    select
        cast(cast(period_id as bigint) as varchar) as period_id,
        description                 as period_description,
        effective_start_date        as start_date,
        effective_end_date          as end_date,
        enrollment_start_date,
        case status
            when 'A' then true
            when 'I' then false
            else null
        end                         as is_active,
        create_date,
        update_date
    from deduped
    where _rn = 1
)

select * from renamed

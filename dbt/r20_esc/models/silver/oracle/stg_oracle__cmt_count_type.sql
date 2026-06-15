{{ config(materialized='table', table_type='iceberg', format='parquet') }}

with source as (
    select * from {{ source('oracle', 'cmt_count_type') }}
),

deduped as (
    select *,
        row_number() over (
            partition by id
            order by _airbyte_extracted_at desc
        ) as _rn
    from source
),

renamed as (
    select
        cast(cast(id as bigint) as varchar) as cmt_count_type_id,
        count_type,
        f_count_app_variable,
        created_date,
        updated_date
    from deduped
    where _rn = 1
)

select * from renamed

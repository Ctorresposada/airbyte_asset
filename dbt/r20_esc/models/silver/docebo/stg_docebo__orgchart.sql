{{ config(materialized='table', table_type='iceberg', format='parquet') }}

with source as (
    select * from {{ source('docebo', 'docebo_orgchart_src') }}
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
        id                  as branch_id,
        lev                 as branch_level,
        code                as branch_code,
        title               as branch_title,
        parent_id,
        parent_code,
        path_ids
    from deduped
    where _rn = 1
)

select * from renamed

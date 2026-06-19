{{ config(materialized='table', table_type='iceberg', format='parquet') }}

-- TAS activity codes — 1 row per activity_code_id.
-- Source delivers 87 rows, 0 PK collisions (no dedup needed).

with source as (
    select * from {{ source('tas', 'activity_code') }}
),

renamed as (
    select
        activity_code_id,
        activity_id,
        activity_desc
    from source
)

select * from renamed

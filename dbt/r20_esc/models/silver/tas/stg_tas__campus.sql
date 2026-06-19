{{ config(materialized='table', table_type='iceberg', format='parquet') }}

-- TAS campus — 1 row per campus_id. Source delivers 895 rows, no PK collisions.

with source as (
    select * from {{ source('tas', 'campus') }}
),

renamed as (
    select
        campus_id,
        client_id,
        campus_code,
        campus_name,
        campus_desc,
        active
    from source
)

select * from renamed

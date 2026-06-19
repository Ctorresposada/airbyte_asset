{{ config(materialized='table', table_type='iceberg', format='parquet') }}

-- TAS clients — 1 row per client_id. Source delivers 397 rows, no PK collisions.

with source as (
    select * from {{ source('tas', 'client') }}
),

renamed as (
    select
        client_id,
        client_name,
        client_desc,
        county_client_code,
        active
    from source
)

select * from renamed

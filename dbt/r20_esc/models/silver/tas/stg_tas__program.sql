{{ config(materialized='table', table_type='iceberg', format='parquet') }}

-- TAS programs — 1 row per program_id. Source delivers 1529 rows, no PK collisions.

with source as (
    select * from {{ source('tas', 'program') }}
),

renamed as (
    select
        program_id,
        org_id,
        org_desc,
        program_type,
        fund_id,
        fiscal_year,
        begin_date,
        end_date,
        insert_date,
        update_date
    from source
)

select * from renamed

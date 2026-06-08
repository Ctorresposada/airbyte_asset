{{ config(materialized='table', table_type='iceberg', format='parquet') }}

with source as (
    select * from {{ source('docebo', 'docebo_users_src') }}
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
        cast(user_id as varchar)   as user_id,
        trim(lower(username))      as username,
        trim(lower(email))         as email,
        fullname                   as full_name
    from deduped
    where _rn = 1
)

select * from renamed

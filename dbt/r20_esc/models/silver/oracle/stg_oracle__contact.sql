{{ config(materialized='table', table_type='iceberg', format='parquet') }}

with source as (
    select * from {{ source('oracle', 'contact') }}
),

deduped as (
    select *,
        row_number() over (
            partition by contact_id
            order by _airbyte_extracted_at desc
        ) as _rn
    from source
),

renamed as (
    select
        cast(contact_id as varchar)      as contact_id,
        first_name,
        middle_name,
        last_name,
        first_name || ' ' || last_name   as full_name,
        email_address                    as email,
        phone,
        fax,
        street_address,
        mailing_address,
        city,
        state,
        zip,
        mailing_city,
        mailing_state,
        mailing_zip,
        prefix,
        suffix,
        contact_type,
        cast(district_id as varchar)     as district_id,
        cast(campus_id as varchar)       as campus_id,
        cast(region_id as varchar)       as region_id,
        cast(county_id as varchar)       as county_id,
        district_number,
        campus_number,
        county_number,
        active_flag                      as is_active,
        date_created,
        date_modified
    from deduped
    where _rn = 1
)

select * from renamed

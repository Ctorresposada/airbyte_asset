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
        cast(cast(district_id as bigint) as varchar)  as district_id,
        cast(cast(campus_id as bigint) as varchar)    as campus_id,
        cast(cast(region_id as bigint) as varchar)    as region_id,
        cast(cast(county_id as bigint) as varchar)    as county_id,
        district_number,
        campus_number,
        county_number,
        case active_flag
            when 'Y' then true
            when 'N' then false
            else null
        end                              as is_active,
        active_flag,
        date_created,
        date_modified
    from deduped
    where _rn = 1
)

select * from renamed

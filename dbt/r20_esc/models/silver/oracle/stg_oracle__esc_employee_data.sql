{{ config(materialized='table', table_type='iceberg', format='parquet') }}

with source as (
    select * from {{ source('oracle', 'esc_employee_data') }}
),

deduped as (
    select *,
        row_number() over (
            partition by employee_id
            order by _airbyte_extracted_at desc
        ) as _rn
    from source
),

renamed as (
    select
        employee_id,
        employee_number,
        user_name,
        firstname,
        last_name,
        name,
        firstname || ' ' || last_name as full_name,
        known_as,
        email_address,
        homephone,
        homeaddress,
        work_phone,
        workfax,
        office_number,
        officecontact,
        division,
        component,
        job_code,
        job_type,
        person_type_id,
        specialty_area,
        assignment_type,
        primary_flag,
        supervisor,
        supervisor_id,
        internal_location
    from deduped
    where _rn = 1
)

select * from renamed

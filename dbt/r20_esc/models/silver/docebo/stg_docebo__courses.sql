{{ config(materialized='table', table_type='iceberg', format='parquet') }}

with source as (
    select * from {{ source('docebo', 'docebo_courses_src') }}
),

deduped as (
    select *,
        row_number() over (
            partition by id_course
            order by _airbyte_extracted_at desc
        ) as _rn
    from source
),

renamed as (
    select
        cast(id_course as varchar)      as course_id,
        name                            as course_title,
        status                          as course_status,
        course_type,
        cast(credits as decimal(10, 2)) as course_credits
    from deduped
    where _rn = 1
)

select * from renamed

{{ config(materialized='table', table_type='iceberg', format='parquet') }}

with source as (
    select * from {{ source('docebo', 'docebo_enrollments_src') }}
),

-- Natural PK is the composite (user_id, course_id). One user enrolls in many
-- courses. Partitioning by user_id alone collapsed 11.244 source rows down
-- to ~1.241 and made it impossible to join to courses.
deduped as (
    select *,
        row_number() over (
            partition by user_id, course_id
            order by _airbyte_extracted_at desc
        ) as _rn
    from source
),

renamed as (
    select
        cast(cast(user_id as bigint) as varchar)   as user_id,
        cast(cast(course_id as bigint) as varchar) as course_id,
        enrollment_status,
        try_cast(substr(enrollment_completion_date, 1, 10) as date) as completion_date
    from deduped
    where _rn = 1
)

select * from renamed

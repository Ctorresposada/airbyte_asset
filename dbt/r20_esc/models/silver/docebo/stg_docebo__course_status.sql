{{ config(materialized='table', table_type='iceberg', format='parquet') }}

-- Latest publication status per course. Bronze receives a row every time the
-- status changes (4037 rows across 2020 courses ~ 2 history events per course).
-- Silver keeps only the most-recent state via Airbyte's extracted_at.

with source as (
    -- Bronze includes ~2017 status events with NULL/empty id (likely deletes
    -- or out-of-band records). Drop them: a course_id is mandatory for any
    -- downstream join.
    select * from {{ source('docebo', 'docebo_course_status_src') }}
    where id is not null and id <> ''
),

deduped as (
    select *,
        row_number() over (
            partition by id
            order by _airbyte_extracted_at desc
        ) as _rn
    from source
),

renamed as (
    select
        id           as course_id,
        is_published
    from deduped
    where _rn = 1
)

select * from renamed

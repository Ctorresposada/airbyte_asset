{{ config(materialized='table', table_type='iceberg', format='parquet') }}

with source as (
    select * from {{ source('connect20_bronze', 'connect20_evaluations') }}
),

-- Dedup is commented out: Connect20 bronze uses incremental append where
-- each daily file contains only new records, so duplicate evaluations rows are
-- not expected. Uncomment statement below if upstream starts resending existing evaluations and deduplication becomes a requirement.
deduped as (
    select *
        -- ,row_number() over (
        --     partition by pk_column
        -- -- file_date desc nulls last — business time, newest file wins / ingested_at desc — tiebreaker for rows where file_date couldn't be parsed (NULL)
        --     order by file_date desc nulls last, ingested_at desc
        -- ) as _rn
    from source
),

renamed as (
    select
        -- Keys
        cast(attendee_id as integer)        as attendee_id,
        cast(sessionid as integer)          as session_id,
        cast(item_id as integer)            as item_id,
        cast(evaluationid as integer)       as evaluation_id,

        -- Evaluation
        evaluationtitle                     as evaluation_title,
        title,
        question_text,
        response_text,
        cast(response_value as decimal(38,18)) as response_value,
        cast(eval_complete as integer)      as eval_complete,
        cast(evalresponsetime as timestamp) as eval_response_time,
        cast(sent_date as timestamp)        as sent_date,
        credit_hours,

        -- Session dates
        cast(startdate as timestamp)        as start_date,
        cast(enddate as timestamp)          as end_date,

        -- Attendee
        firstname,
        lastname,
        email,
        position,
        cast(school_id as integer)          as school_id,
        school,
        cast(district_id as integer)        as district_id,
        district,

        -- Counts
        cast(attendeecount as integer)      as attendee_count,
        cast(attendeecountall as integer)   as attendee_count_all,
        presenters,

        -- Audit
        file_name,
        file_date,
        ingested_at                             as ingested_at_bronze,
        cast(current_timestamp as timestamp)    as ingested_at
    from deduped
  --  where _rn = 1
)

select * from renamed

{{ config(
    materialized='table',
    table_type='iceberg',
    format='parquet'
) }}

-- Grabs full table in bronze since bronze layer is append-only
with source as (
    select * from {{ source('connect20_bronze', 'connect20_schedule12') }}
),

-- Dedup is commented out: Connect20 bronze uses incremental append where
-- each daily file contains only new records, so duplicate session rows are
-- not expected. Uncomment if upstream starts resending existing sessions and deduplication becomes a requirement.
deduped as (
    select *
    --    , row_number() over (
    --         partition by pk_column
    -- -- file_date desc nulls last — business time, newest file wins / ingested_at desc — tiebreaker for rows where file_date couldn't be parsed (NULL)
    --         order by file_date desc nulls last, ingested_at desc
    --     ) as _rn
    from source
),

renamed as (
    select
        -- Keys
        cast(sessionid as integer)          as session_id,
        cast(event_id as integer)           as event_id,

        -- Session info
        session_title,
        event_title,
        event_type,
        session_type,

        -- Schedule
        cast(start_date as timestamp)       as start_date,
        start_time,
        cast(end_date as timestamp)         as end_date,
        end_time,
        meeting_room_name,
        schedule,
        schedule1,

        -- Attendance
        cast(attendee_count as integer)     as attendee_count,
        cast(attendee_count_all as integer) as attendee_count_all,
        active,
        multi_enroll,

        -- Credits / evaluation
        credits_available,
        evaluation_chosen,
        cast(standard_fee as double)        as standard_fee,
        discounts,
        funding,

        -- People
        creator,
        instructor,
        contact_person,
        budget_manager,

        -- Classification
        audience,
        subject,
        recommended_event_titles,
        critical_success_factors,
        extended_learning_24,
        core_service_41,

        -- Budget coding
        expenditure_budget_code,
        revenue_budget_code,
        contact_primary_dept,
        budget_manager_primary_dept,

        -- Audit
        file_name,
        file_date,
        ingested_at                             as ingested_at_bronze,
        cast(current_timestamp as timestamp)    as ingested_at
    from deduped
  --  where _rn = 1
)

select * from renamed

{#
    Materialization: incremental + append
    -------------------------------------
    Bronze = faithful copy of raw Connect20 schedule records.
    Types are already correct in the source Parquet. Columns whose names
    contain spaces are aliased to snake_case here; the underlying values
    are not modified — casting belongs in silver.

    On the very first run, is_incremental() is False → ALL files loaded.
    On every subsequent run, is_incremental() is True → only files whose
    file_name is not yet present in this bronze table are processed.

    Backfill a specific file: DELETE its rows from this table in Athena,
    then re-run dbt — the NOT IN guard lets that file_name through again.
#}
{{ config(
    materialized='incremental',
    incremental_strategy='append',
    table_type='iceberg',
    format='parquet',
    s3_data_dir=env_var('BRONZE_BUCKET') ~ 'connect20'
) }}

with source as (

    select

        -- ------------------------------------------------------------------
        -- Ingestion metadata
        -- ------------------------------------------------------------------
        "$path"                                                                   as source_path,
        regexp_extract("$path", '[^/]+$')                                         as file_name,
        try(
            date_parse(
                regexp_extract(regexp_extract("$path", '[^/]+$'), '(\d{8})'),
                '%Y%m%d'
            )
        )                                                                         as file_date,
        cast(current_timestamp as timestamp)                                       as ingested_at,

        -- ------------------------------------------------------------------
        -- Session identity
        -- ------------------------------------------------------------------
        sessionid,
        "session title"                                                           as session_title,
        "event title"                                                             as event_title,
        "event id"                                                                as event_id,
        "event type"                                                              as event_type,
        "session type"                                                            as session_type,

        -- ------------------------------------------------------------------
        -- Schedule / logistics
        -- ------------------------------------------------------------------
        "start date"                                                              as start_date,
        "start time"                                                              as start_time,
        "end date"                                                                as end_date,
        "end time"                                                                as end_time,
        "meeting room name"                                                       as meeting_room_name,
        schedule,
        schedule1,

        -- ------------------------------------------------------------------
        -- Attendance
        -- ------------------------------------------------------------------
        "attendee count"                                                          as attendee_count,
        "attendee count all"                                                      as attendee_count_all,
        active,
        "multi enroll"                                                            as multi_enroll,

        -- ------------------------------------------------------------------
        -- Credits / evaluation
        -- ------------------------------------------------------------------
        "credits available"                                                       as credits_available,
        "evaluation chosen"                                                       as evaluation_chosen,
        "standard fee"                                                            as standard_fee,
        discounts,
        funding,

        -- ------------------------------------------------------------------
        -- People
        -- ------------------------------------------------------------------
        creator,
        instructor,
        "contact person"                                                          as contact_person,
        "budget manager"                                                          as budget_manager,

        -- ------------------------------------------------------------------
        -- Classification / metadata
        -- ------------------------------------------------------------------
        audience,
        subject,
        "recommended event titles"                                                as recommended_event_titles,
        "critical success factors"                                                as critical_success_factors,
        "2.4 extended learning opportunities"                                     as extended_learning_24,
        "4.1 core service"                                                        as core_service_41,

        -- ------------------------------------------------------------------
        -- Budget coding
        -- ------------------------------------------------------------------
        "expenditure budget code"                                                 as expenditure_budget_code,
        "revenue budget code"                                                     as revenue_budget_code,
        "contact primary dept"                                                    as contact_primary_dept,
        "budget manager primary dept"                                             as budget_manager_primary_dept

    from {{ source('connect20_schedule12_raw', 'connect20_schedule12') }}

    -- -----------------------------------------------------------------------
    -- Incremental filter — Incremental Append
    -- Only injected on run #2 onwards (is_incremental() = True).
    -- Each daily file is loaded exactly once; idempotency key = file_name.
    -- -----------------------------------------------------------------------
    {% if is_incremental() %}
    where regexp_extract("$path", '[^/]+$') not in (
        select distinct file_name from {{ this }}
    )
    {% endif %}

)

select * from source

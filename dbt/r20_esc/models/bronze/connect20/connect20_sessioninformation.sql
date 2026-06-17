{#
    Materialization: incremental + append
    -------------------------------------
    Bronze = faithful copy of raw Connect20 session information records.
    Types are already correct in the source Parquet. Columns whose names
    contain spaces or special characters are aliased to snake_case here;
    values are not modified — casting belongs in silver.

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
        "date started"                                                            as date_started,
        "date ended"                                                              as date_ended,
        "date attended"                                                           as date_attended,
        "meeting room name"                                                       as meeting_room_name,
        "session schedule dates"                                                  as session_schedule_dates,

        -- ------------------------------------------------------------------
        -- Attendee
        -- ------------------------------------------------------------------
        useremail,
        firstname,
        lastname,
        completed,
        "group member of"                                                         as group_member_of,
        "multi credit override"                                                   as multi_credit_override,

        -- ------------------------------------------------------------------
        -- Payment
        -- ------------------------------------------------------------------
        sessionfee,
        paymentmethod,
        feepaid,
        "promotional code(s)"                                                     as promotional_codes,

        -- ------------------------------------------------------------------
        -- Organization / classification
        -- ------------------------------------------------------------------
        organization,
        district,
        "identification code"                                                     as identification_code,
        "customer number"                                                         as customer_number,
        "site type"                                                               as site_type,
        "member group"                                                            as member_group

    from {{ source('connect20_sessioninformation_raw', 'connect20_sessioninformation') }}

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

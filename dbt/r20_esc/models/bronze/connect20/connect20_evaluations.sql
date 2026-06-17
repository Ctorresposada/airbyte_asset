{#
    Materialization: incremental + append
    -------------------------------------
    Bronze = faithful copy of raw Connect20 evaluation responses.
    Types are already correct in the source Parquet (timestamps, decimal,
    int) so no casting is needed here — that belongs in silver.

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
        -- Evaluation response columns (types as delivered by RAW Layer)
        -- ------------------------------------------------------------------
        question_text,
        response_text,
        response_value,
        attendee_id,
        sessionid,
        item_id,
        evaluationid,
        evaluationtitle,
        title,
        startdate,
        enddate,
        firstname,
        lastname,
        school_id,
        district_id,
        school,
        district,
        position,
        email,
        attendeecount,
        attendeecountall,
        presenters,
        eval_complete,
        sent_date,
        credit_hours,
        evalresponsetime

    from {{ source('connect20_evaluationinformation_raw', 'connect20_evaluationinformation') }}

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

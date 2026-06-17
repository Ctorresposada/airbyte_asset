{#
    Materialization: incremental + append
    ------------------------------------
    Bronze = faithful copy of raw. No type casting here — all 70 source
    columns are kept as STRING exactly as OpenCSVSerde delivers them.
    Casting to proper types (dates, decimals, integers) is handled in the
    silver staging model (stg_ascender__invoice).

    On the very first run, is_incremental() is False, so the WHERE filter at
    the bottom is skipped and ALL files in the raw folder are loaded. On every
    subsequent run, is_incremental() is True and only files not yet present in
    this bronze table are processed.

    Backfill a specific file: DELETE its rows from this table in Athena, then
    re-run dbt — the NOT IN guard will let that file_name through again.
#}
{{ config(
    materialized='incremental',
    incremental_strategy='append',
    table_type='iceberg',
    format='parquet',
    s3_data_dir=env_var('BRONZE_BUCKET') ~ 'ascender'
) }}

with source as (

    select

        -- ------------------------------------------------------------------
        -- Ingestion metadata
        -- $path is a virtual column available in Athena on any S3-backed table.
        -- It holds the full S3 URI of the file the row came from.
        -- ------------------------------------------------------------------
        "$path"                                                                   as source_path,

        -- Last path segment → e.g. "invoice_20250601120000.csv"
        regexp_extract("$path", '[^/]+$')                                         as file_name,

        -- 8-digit date extracted from the file name, parsed to DATE.
        -- try() returns NULL instead of throwing on unexpected file names.
        try(
            date_parse(
                regexp_extract(regexp_extract("$path", '[^/]+$'), '(\d{8})'),
                '%Y%m%d'
            )
        )                                                                         as file_date,

        -- Timestamp of when this dbt run ingested the row.
        cast(current_timestamp as timestamp)                                       as ingested_at,

        -- ------------------------------------------------------------------
        -- Invoice header (all string — as delivered by RAW)
        -- ------------------------------------------------------------------
        invoice_number,
        customer_number,
        requested_by,
        request_date,
        invoiced_by,
        due_date,
        department_id,
        module,
        original_amount,

        -- ------------------------------------------------------------------
        -- Customer / billing address
        -- ------------------------------------------------------------------
        cust_nbr,
        customer_name,
        stat_flg,
        addr_atn,
        addr_str,
        addr_cty,
        addr_st,
        addr_zip,
        addr_zip4,
        pri_contact,
        phone_ac,
        phone_nbr,
        phone_nbr_ext,
        fax_ac,
        fax_nbr,
        po_required,
        email,
        local_use,
        dt_last_used,
        module_1,

        -- ------------------------------------------------------------------
        -- Line item / product
        -- ------------------------------------------------------------------
        vendor_nbr,
        invc_nbr,
        product_seq_nbr,
        product_nbr,
        product_description,
        product_unit_iss,
        quantity,
        unit_price,
        total_amount,

        -- ------------------------------------------------------------------
        -- Adjustment
        -- ------------------------------------------------------------------
        invc_nbr_1,
        adjust_seq_nbr,
        dt_adjust,
        user_id,

        -- ------------------------------------------------------------------
        -- Budget coding — first allocation
        -- ------------------------------------------------------------------
        fund,
        fscl_yr,
        func,
        obj,
        sobj,
        org,
        pgm,
        ed_span,
        proj_dtl,
        adjustment_amount,
        adjust_reason,
        pymt_nbr,

        -- ------------------------------------------------------------------
        -- Payment
        -- ------------------------------------------------------------------
        invc_nbr_2,
        dts,
        payment_amount,

        -- ------------------------------------------------------------------
        -- Budget coding — payment allocation
        -- ------------------------------------------------------------------
        fund_1,
        fscl_yr_1,
        func_1,
        obj_1,
        sobj_1,
        org_1,
        pgm_1,
        ed_span_1,
        proj_dtl_1,

        -- ------------------------------------------------------------------
        -- Reversal
        -- ------------------------------------------------------------------
        dt_reverse,
        reverse_user_id,
        over_pymt_flg,
        module_2

    from {{ source('ascender_raw', 'ascender_invoice') }}

    -- -----------------------------------------------------------------------
    -- Incremental filter — Full Load Append
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

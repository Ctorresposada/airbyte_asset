{{ config(materialized='table', table_type='iceberg', format='parquet') }}

with source as (
    select * from {{ source('oracle', 'cmt_range_price_forms') }}
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
        cast(id as varchar)                          as range_price_id,
        cast(cast(cmt_form_id as bigint) as varchar) as cmt_form_id,
        cast(cast(period_id as bigint) as varchar)   as period_id,
        range_name,
        range_label,
        range_level,
        range_min,
        range_max,
        install_chrg,
        install_label,
        per_stdnt_chrg,
        per_stdnt_label,
        fee_amt,
        fee_label,
        gen1_amt,
        gen1_label,
        min_price,
        max_price,
        pretext_desc,
        pretext_label,
        posttext_desc,
        posttext_label,
        item_description4,
        price4
    from deduped
    where _rn = 1
)

select * from renamed

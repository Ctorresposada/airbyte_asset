{{ config(materialized='table', table_type='iceberg', format='parquet') }}

with source as (
    select * from {{ source('oracle', 'cmt_form_item') }}
),

deduped as (
    select *,
        row_number() over (
            partition by cmt_form_item_id
            order by _airbyte_extracted_at desc
        ) as _rn
    from source
),

renamed as (
    select
        cast(cmt_form_item_id as varchar) as cmt_form_item_id,
        cast(cmt_form_id as varchar)      as cmt_form_id,
        cast(period_id as varchar)        as period_id,
        cmt_group,
        description,
        unit_price,
        quantity,
        sub_total,
        display_order,
        commitment_for,
        district_will,
        center_will,
        center_will_ext,
        required,
        default_selected,
        effective_start_date,
        effective_end_date,
        date_created,
        date_modified
    from deduped
    where _rn = 1
)

select * from renamed

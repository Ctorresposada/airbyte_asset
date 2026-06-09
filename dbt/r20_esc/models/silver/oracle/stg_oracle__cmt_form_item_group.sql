{{ config(materialized='table', table_type='iceberg', format='parquet') }}

with source as (
    select * from {{ source('oracle', 'cmt_form_item_group') }}
),

deduped as (
    select *,
        row_number() over (
            partition by cmt_form_item_group_id
            order by _airbyte_extracted_at desc
        ) as _rn
    from source
),

renamed as (
    select
        cast(cmt_form_item_group_id as varchar)    as cmt_form_item_group_id,
        cast(cast(period_id as bigint) as varchar) as period_id,
        title,
        description,
        page,
        counts_used,
        count_type_id,
        allow_select_all,
        case active
            when 'Y' then true
            when 'N' then false
            else null
        end                                     as is_active,
        date_created,
        date_modified
    from deduped
    where _rn = 1
)

select * from renamed

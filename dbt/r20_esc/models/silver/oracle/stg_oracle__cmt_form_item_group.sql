{{ config(materialized='table', table_type='iceberg', format='parquet') }}

with source as (
    select * from {{ source('oracle', 'cmt_form_item_group') }}
),

-- Natural PK is the composite (period_id, cmt_form_item_group_id): the same
-- group id is reused across periods with different titles (e.g. id=1 is
-- "2013 Purchasing Cooperative" in periods 1-17 and "Region 20 Purchasing
-- Cooperative" in 18-21). Partitioning by id alone collapsed 728 rows down
-- to 97 and made the cmt_form -> cmt_form_item_group join in
-- fct_cmt_offering return zero matches for most forms.
deduped as (
    select *,
        row_number() over (
            partition by period_id, cmt_form_item_group_id
            order by _airbyte_extracted_at desc
        ) as _rn
    from source
),

renamed as (
    select
        cast(cast(cmt_form_item_group_id as bigint) as varchar) as cmt_form_item_group_id,
        cast(cast(period_id as bigint) as varchar) as period_id,
        title,
        description,
        page,
        counts_used,
        cast(cast(count_type_id as bigint) as varchar) as count_type_id,
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

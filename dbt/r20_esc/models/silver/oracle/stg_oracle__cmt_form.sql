{{ config(materialized='table', table_type='iceberg', format='parquet') }}

with source as (
    select * from {{ source('oracle', 'cmt_form') }}
),

deduped as (
    select *,
        row_number() over (
            partition by cmt_form_id, period_id
            order by _airbyte_extracted_at desc
        ) as _rn
    from source
),

renamed as (
    select
        cast(cast(cmt_form_id as bigint) as varchar)     as cmt_form_id,
        cast(cast(period_id as bigint) as varchar)       as period_id,
        cast(cmt_group_id as varchar)                    as cmt_group_id,
        cast(cast(cmt_order_id as bigint) as varchar)    as cmt_order_id,
        cast(cast(commitment_id as bigint) as varchar)   as commitment_id,
        cast(cast(esc_contact_id as bigint) as varchar)  as esc_contact_id,
        cast(esc_contact_id2 as varchar)                 as esc_contact_id2,
        cast(cast(parent_id as bigint) as varchar)       as parent_id,
        cast(cast(pdetail_id as bigint) as varchar)      as pdetail_id,
        cast(created_by as varchar)      as created_by,
        cast(updated_by as varchar)      as updated_by,
        cast(contact1 as varchar)        as contact1,
        cast(contact2 as varchar)        as contact2,
        cmt_division,
        cmt_option,
        cmt_form_name,
        cmt_submit_details,
        page_link,
        budgetcode,
        connect20_group,
        cbm_type,
        commitment_manager,
        netvision_member,
        sort_order,
        apply_disc,
        onchange,
        jscript,
        esc_contact_fname,
        esc_contact_mname,
        esc_contact_lname,
        esc_contact_email,
        item_decsription,               -- typo preservado do sistema de origem
        price,
        item_qty,
        item_extd_price,
        enrllsz,
        item_description1,
        price1,
        item_description2,
        price2,
        item_description3,
        price3,
        item_description4,
        price4,
        effective_start_date,
        effective_end_date,
        case active
            when 'Y' then true
            when 'N' then false
            else null
        end                              as is_active,
        active,
        date_created,
        date_updated
    from deduped
    where _rn = 1
)

select * from renamed

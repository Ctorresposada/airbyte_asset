{{ config(materialized='table', table_type='iceberg', format='parquet') }}

with source as (
    select * from {{ source('oracle', 'cmt_enrollment') }}
),

deduped as (
    select *,
        row_number() over (
            partition by cmt_enrt_id
            order by _airbyte_extracted_at desc
        ) as _rn
    from source
),

renamed as (
    select
        cast(cast(cmt_enrt_id as bigint) as varchar)        as cmt_enrt_id,
        cast(cast(cmt_form_id as bigint) as varchar)        as cmt_form_id,
        cmt_form_name,
        cmt_option,
        cast(cast(period_id as bigint) as varchar)          as period_id,
        cast(cast(contact_id as bigint) as varchar)         as contact_id,
        cast(cast(org_id as bigint) as varchar)             as org_id,
        org_type,
        enrolling_org,
        cast(cast(enrolling_org_id as bigint) as varchar)   as enrolling_org_id,
        enroll_flag,
        final_submit_flag,
        invoice_flag,
        k12_review_flag,
        payment_method,
        purchase_order,
        invoice_date,
        submit_date,
        creation_date,
        last_update_date,
        admin_update_date,
        calc_price,
        calc_price1,
        nv_price,
        non_nv_price,
        quantity,
        quantity1,
        solstar,
        a_busvisits,
        a_studvisits,
        b_busvisits,
        b_studvisits,
        cast(cast(created_by as bigint) as varchar)         as created_by,
        cast(cast(updated_by as bigint) as varchar)         as updated_by,
        cast(cast(submitted_by as bigint) as varchar)       as submitted_by,
        admin_updated_by,
        esc20_created_by,
        -- Custom form responses preserved (Oracle APEX dynamic fields)
        label1, label2, label3, label4, label5, label6, label7, label8, label9, label10,
        value1, value2, value3, value4, value5, value6, value7, value8, value9, value10,
        value11, value12, value13, value14, value15, value16, value17, value18, value19
    from deduped
    where _rn = 1
)

select * from renamed

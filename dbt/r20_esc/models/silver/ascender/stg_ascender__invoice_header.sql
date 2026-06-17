{{ config(materialized='table', table_type='iceberg', format='parquet') }}

-- Invoice header — 1 row per invoice_number. Bronze é full-snapshot append,
-- então pegamos só o latest snapshot (max file_date — 1:1 com filename)
-- e fazemos overwrite (per Isadora, Slack 2026-06-17). Não usamos
-- ingested_at porque arquivos ingeridos no mesmo dbt run compartilham
-- current_timestamp. Header é estável dentro do snapshot — validamos via
-- Athena: 0 invoices com multi-customer/multi-request_date/multi-amount.

with latest_snapshot as (
    select *
    from {{ source('ascender_bronze', 'ascender_invoice') }}
    where file_date = (select max(file_date) from {{ source('ascender_bronze', 'ascender_invoice') }})
),

deduped as (
    select
        invoice_number,
        any_value(customer_number)                                                  as customer_number,
        any_value(requested_by)                                                     as requested_by,
        any_value(try(date_parse(nullif(request_date, ''), '%m/%d/%Y')))            as request_date,
        any_value(invoiced_by)                                                      as invoiced_by,
        any_value(try(date_parse(nullif(due_date, ''), '%m/%d/%Y')))                as due_date,
        any_value(department_id)                                                    as department_id,
        any_value(module)                                                           as module,
        any_value(try(cast(nullif(original_amount, '') as decimal(18,2))))          as original_amount,
        any_value(cust_nbr)                                                         as cust_nbr,
        any_value(customer_name)                                                    as customer_name,
        any_value(stat_flg)                                                         as customer_status,
        any_value(addr_atn)                                                         as customer_addr_attention,
        any_value(addr_str)                                                         as customer_addr_street,
        any_value(addr_cty)                                                         as customer_addr_city,
        any_value(addr_st)                                                          as customer_addr_state,
        any_value(addr_zip)                                                         as customer_addr_zip,
        any_value(addr_zip4)                                                        as customer_addr_zip4,
        any_value(pri_contact)                                                      as primary_contact,
        any_value(phone_ac)                                                         as phone_area_code,
        any_value(phone_nbr)                                                        as phone_number,
        any_value(phone_nbr_ext)                                                    as phone_extension,
        any_value(fax_ac)                                                           as fax_area_code,
        any_value(fax_nbr)                                                          as fax_number,
        any_value(case when po_required = 'Y' then true when po_required = 'N' then false end) as po_required,
        any_value(email)                                                            as email,
        any_value(local_use)                                                        as local_use,
        any_value(try(date_parse(nullif(dt_last_used, ''), '%Y%m%d')))              as last_used_date,
        any_value(module_1)                                                         as module_customer,
        any_value(file_name)                                                        as source_file,
        any_value(file_date)                                                        as snapshot_date,
        any_value(ingested_at)                                                      as ingested_at
    from latest_snapshot
    where invoice_number is not null and invoice_number <> ''
    group by invoice_number
)

select * from deduped

{{ config(materialized='table', table_type='iceberg', format='parquet') }}

-- Invoice line items — 1 row per (invoice_number, product_seq_nbr).
-- Filtra latest snapshot via max(file_date) — 1:1 com filename.
-- Validado via Athena: 56003 line keys no latest snapshot, 0 inconsistências.

with latest_snapshot as (
    select *
    from {{ source('ascender_bronze', 'ascender_invoice') }}
    where file_date = (select max(file_date) from {{ source('ascender_bronze', 'ascender_invoice') }})
),

deduped as (
    select
        invoice_number,
        product_seq_nbr,
        any_value(vendor_nbr)                                              as vendor_number,
        any_value(invc_nbr)                                                as line_invoice_number,
        any_value(product_nbr)                                             as product_number,
        any_value(product_description)                                     as product_description,
        any_value(product_unit_iss)                                        as product_unit_issued,
        any_value(try(cast(nullif(quantity, '') as decimal(18,4))))        as quantity,
        any_value(try(cast(nullif(unit_price, '') as decimal(18,4))))      as unit_price,
        any_value(try(cast(nullif(total_amount, '') as decimal(18,2))))    as total_amount,
        any_value(file_name)                                               as source_file,
        any_value(file_date)                                               as snapshot_date,
        any_value(ingested_at)                                             as ingested_at
    from latest_snapshot
    where invoice_number is not null and invoice_number <> ''
      and product_seq_nbr is not null and product_seq_nbr <> ''
    group by invoice_number, product_seq_nbr
)

select * from deduped

{{ config(materialized='table', table_type='iceberg', format='parquet') }}

-- Invoice payments — 1 row per payment allocation event.
-- O bronze faz cross-join de payment_alloc com product_seq_nbr (line),
-- então o pagamento "real" se repete N_lines vezes. Aqui colapsamos via
-- SELECT DISTINCT nas cols do pagamento (drop product_seq_nbr, drop adjust cols).
-- PK natural composto: (invoice_number, pymt_nbr, payment_timestamp, payment_amount, GL coding 9 cols).
-- Surrogate key payment_id = md5 hash desse natural key.

with latest_snapshot as (
    select *
    from {{ source('ascender_bronze', 'ascender_invoice') }}
    where file_date = (select max(file_date) from {{ source('ascender_bronze', 'ascender_invoice') }})
),

payment_rows as (
    select distinct
        invoice_number,
        pymt_nbr,
        invc_nbr_2,
        dts,
        payment_amount,
        fund_1,
        fscl_yr_1,
        func_1,
        obj_1,
        sobj_1,
        org_1,
        pgm_1,
        ed_span_1,
        proj_dtl_1
    from latest_snapshot
    where pymt_nbr is not null and pymt_nbr <> ''
),

casted as (
    select
        {{ dbt_utils.generate_surrogate_key([
            'invoice_number', 'pymt_nbr', 'dts', 'payment_amount',
            'fund_1', 'fscl_yr_1', 'func_1', 'obj_1', 'sobj_1', 'org_1', 'pgm_1', 'ed_span_1', 'proj_dtl_1'
        ]) }}                                                                       as payment_id,
        invoice_number,
        pymt_nbr,
        invc_nbr_2                                                                  as payment_invoice_number,
        try(date_parse(substr(nullif(dts, ''), 1, 14), '%Y%m%d%H%i%S'))             as payment_timestamp,
        try(cast(nullif(payment_amount, '') as decimal(18,2)))                      as payment_amount,
        nullif(trim(fund_1), '')                                                    as gl_fund,
        nullif(trim(fscl_yr_1), '')                                                 as gl_fiscal_year,
        nullif(trim(func_1), '')                                                    as gl_function,
        nullif(trim(obj_1), '')                                                     as gl_object,
        nullif(trim(sobj_1), '')                                                    as gl_sub_object,
        nullif(trim(org_1), '')                                                     as gl_organization,
        nullif(trim(pgm_1), '')                                                     as gl_program,
        nullif(trim(ed_span_1), '')                                                 as gl_education_span,
        nullif(trim(proj_dtl_1), '')                                                as gl_project_detail
    from payment_rows
)

select * from casted

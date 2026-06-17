{{ config(materialized='table', table_type='iceberg', format='parquet') }}

-- Invoice adjustments — só rows com adjust_seq_nbr populado.
-- Inclui o budget allocation (GL coding) do adjustment (fund, fscl_yr, ...)
-- e os campos de reversal (dt_reverse, reverse_user_id, over_pymt_flg).
-- PK: (invoice_number, adjust_seq_nbr).

with latest_snapshot as (
    select *
    from {{ source('ascender_bronze', 'ascender_invoice') }}
    where file_date = (select max(file_date) from {{ source('ascender_bronze', 'ascender_invoice') }})
),

deduped as (
    select
        invoice_number,
        adjust_seq_nbr,
        any_value(invc_nbr_1)                                                       as adjustment_invoice_number,
        any_value(try(date_parse(nullif(dt_adjust, ''), '%Y%m%d')))                 as adjustment_date,
        any_value(user_id)                                                          as adjustment_user_id,
        any_value(try(cast(nullif(adjustment_amount, '') as decimal(18,2))))        as adjustment_amount,
        any_value(adjust_reason)                                                    as adjustment_reason,
        any_value(fund)                                                             as gl_fund,
        any_value(fscl_yr)                                                          as gl_fiscal_year,
        any_value(func)                                                             as gl_function,
        any_value(obj)                                                              as gl_object,
        any_value(sobj)                                                             as gl_sub_object,
        any_value(org)                                                              as gl_organization,
        any_value(pgm)                                                              as gl_program,
        any_value(ed_span)                                                          as gl_education_span,
        any_value(proj_dtl)                                                         as gl_project_detail,
        any_value(try(date_parse(nullif(dt_reverse, ''), '%Y%m%d')))                as reversal_date,
        any_value(reverse_user_id)                                                  as reversal_user_id,
        any_value(case when over_pymt_flg = 'Y' then true when over_pymt_flg = 'N' then false end) as overpayment_flag,
        any_value(module_2)                                                         as module_reversal,
        any_value(file_name)                                                        as source_file,
        any_value(file_date)                                                        as snapshot_date,
        any_value(ingested_at)                                                      as ingested_at
    from latest_snapshot
    where invoice_number is not null and invoice_number <> ''
      and adjust_seq_nbr is not null and adjust_seq_nbr <> ''
    group by invoice_number, adjust_seq_nbr
)

select * from deduped

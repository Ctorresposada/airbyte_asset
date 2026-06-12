-- DQ analysis: NULL and empty-string distribution on Ascender invoice key columns
-- OpenCSVSerde delivers missing fields as empty strings ('') not NULLs, so
-- both conditions are checked together as "blank".
--
-- Columns checked:
--   invoice_number  — top-level invoice identifier; must not be blank.
--   invc_nbr        — internal invoice number on the line item; must not be blank.
--   cust_nbr        — customer number; must not be blank.
--   customer_number — second customer identifier (relation to cust_nbr TBD).
--   vendor_nbr      — vendor on the line item; expected blank on non-vendor rows.
--   product_nbr     — product code; expected blank when no product applies.
--   total_amount    — line-item total; blank here means the amount is missing.
--
-- Observed: pending first run.
-- Threshold for test promotion:
--   - invoice_number: not_null + not_empty (PK candidate — enforce once confirmed).
--   - invc_nbr:       not_null + not_empty.
--   - cust_nbr:       not_null + not_empty.
--   - vendor_nbr / product_nbr: warn only — blanks may be by design on header rows.

select
    count(*)                                                                        as total_rows,

    -- invoice_number
    sum(case when invoice_number  is null or invoice_number  = '' then 1 else 0 end) as blank_invoice_number,
    round(
        sum(case when invoice_number  is null or invoice_number  = '' then 1.0 else 0 end)
        * 100.0 / count(*), 2
    )                                                                               as pct_blank_invoice_number,

    -- invc_nbr (internal invoice number on the line item)
    sum(case when invc_nbr        is null or invc_nbr        = '' then 1 else 0 end) as blank_invc_nbr,
    round(
        sum(case when invc_nbr        is null or invc_nbr        = '' then 1.0 else 0 end)
        * 100.0 / count(*), 2
    )                                                                               as pct_blank_invc_nbr,

    -- cust_nbr
    sum(case when cust_nbr        is null or cust_nbr        = '' then 1 else 0 end) as blank_cust_nbr,
    round(
        sum(case when cust_nbr        is null or cust_nbr        = '' then 1.0 else 0 end)
        * 100.0 / count(*), 2
    )                                                                               as pct_blank_cust_nbr,

    -- customer_number (may overlap with cust_nbr — compare pct_blank to understand)
    sum(case when customer_number  is null or customer_number = '' then 1 else 0 end) as blank_customer_number,
    round(
        sum(case when customer_number  is null or customer_number = '' then 1.0 else 0 end)
        * 100.0 / count(*), 2
    )                                                                               as pct_blank_customer_number,

    -- vendor_nbr
    sum(case when vendor_nbr      is null or vendor_nbr      = '' then 1 else 0 end) as blank_vendor_nbr,
    round(
        sum(case when vendor_nbr      is null or vendor_nbr      = '' then 1.0 else 0 end)
        * 100.0 / count(*), 2
    )                                                                               as pct_blank_vendor_nbr,

    -- product_nbr
    sum(case when product_nbr     is null or product_nbr     = '' then 1 else 0 end) as blank_product_nbr,
    round(
        sum(case when product_nbr     is null or product_nbr     = '' then 1.0 else 0 end)
        * 100.0 / count(*), 2
    )                                                                               as pct_blank_product_nbr,

    -- total_amount
    sum(case when total_amount    is null or total_amount    = '' then 1 else 0 end) as blank_total_amount,
    round(
        sum(case when total_amount    is null or total_amount    = '' then 1.0 else 0 end)
        * 100.0 / count(*), 2
    )                                                                               as pct_blank_total_amount

from {{ source('ascender_raw', 'ascender_invoice') }}

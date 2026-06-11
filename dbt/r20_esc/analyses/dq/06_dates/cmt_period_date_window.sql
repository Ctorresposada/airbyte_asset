-- DQ analysis: date range sanity on cmt_period
-- Observed 2026-06-10: min_start 2007-09-01, max_start 2027-09-01,
--   min_end 2008-08-31, max_end 2028-08-31, 0 inverted, 0 null on
--   either bound. Dates up to 2028 are expected for planned periods.
-- Threshold for test promotion:
--   - effective_start_date and effective_end_date: not_null
--   - inverted_count: hard fail if > 0 (start > end is invalid)
--   - max_end clamp: configurable upper bound to flag distant typos

select
    cast(min(effective_start_date) as varchar) as min_start,
    cast(max(effective_start_date) as varchar) as max_start,
    cast(min(effective_end_date)   as varchar) as min_end,
    cast(max(effective_end_date)   as varchar) as max_end,
    sum(case when effective_start_date > effective_end_date then 1 else 0 end) as inverted_count,
    sum(case when effective_start_date is null then 1 else 0 end) as null_start,
    sum(case when effective_end_date   is null then 1 else 0 end) as null_end
from {{ source('oracle', 'cmt_period') }}

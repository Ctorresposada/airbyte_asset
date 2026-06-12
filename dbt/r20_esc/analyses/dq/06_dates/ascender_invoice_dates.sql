-- DQ analysis: date string validation on Ascender invoice date columns
-- All five date columns arrive as strings in YYYYMMDD format (e.g. "20250601").
-- This analysis classifies each value into four buckets per column:
--   blank       — NULL or empty string (may be valid for optional date fields)
--   bad_format  — present but not exactly 8 digits (wrong format or garbage)
--   unparseable — 8 digits but not a valid calendar date (e.g. "20250631")
--   valid       — parses cleanly with date_parse(col, '%Y%m%d')
--
-- Columns checked: request_date, due_date, dt_last_used, dt_adjust, dt_reverse
--
-- Observed: pending first run.
-- Threshold for test promotion:
--   - request_date / due_date: warn if bad_format or unparseable > 0
--     (these are mandatory header fields; silver casts them with try() so
--     bad values silently become NULL — this analysis surfaces the count).
--   - dt_adjust / dt_reverse: warn only — these are conditional on whether
--     an adjustment or reversal exists for that row.
--   - dt_last_used: informational only.

with classified as (
    select
        -- request_date
        case
            when request_date is null or request_date = ''                     then 'blank'
            when not regexp_like(request_date, '^\d{8}$')                     then 'bad_format'
            when try(date_parse(request_date,  '%Y%m%d')) is null             then 'unparseable'
            else                                                                    'valid'
        end as request_date_status,

        -- due_date
        case
            when due_date is null or due_date = ''                             then 'blank'
            when not regexp_like(due_date, '^\d{8}$')                         then 'bad_format'
            when try(date_parse(due_date,      '%Y%m%d')) is null             then 'unparseable'
            else                                                                    'valid'
        end as due_date_status,

        -- dt_last_used
        case
            when dt_last_used is null or dt_last_used = ''                     then 'blank'
            when not regexp_like(dt_last_used, '^\d{8}$')                     then 'bad_format'
            when try(date_parse(dt_last_used,  '%Y%m%d')) is null             then 'unparseable'
            else                                                                    'valid'
        end as dt_last_used_status,

        -- dt_adjust
        case
            when dt_adjust is null or dt_adjust = ''                           then 'blank'
            when not regexp_like(dt_adjust, '^\d{8}$')                        then 'bad_format'
            when try(date_parse(dt_adjust,     '%Y%m%d')) is null             then 'unparseable'
            else                                                                    'valid'
        end as dt_adjust_status,

        -- dt_reverse
        case
            when dt_reverse is null or dt_reverse = ''                         then 'blank'
            when not regexp_like(dt_reverse, '^\d{8}$')                       then 'bad_format'
            when try(date_parse(dt_reverse,    '%Y%m%d')) is null             then 'unparseable'
            else                                                                    'valid'
        end as dt_reverse_status

    from {{ source('ascender_raw', 'ascender_invoice') }}
)

select
    'request_date'  as date_column, request_date_status  as status, count(*) as n from classified group by request_date_status
union all
select 'due_date',     due_date_status,     count(*) from classified group by due_date_status
union all
select 'dt_last_used', dt_last_used_status, count(*) from classified group by dt_last_used_status
union all
select 'dt_adjust',    dt_adjust_status,    count(*) from classified group by dt_adjust_status
union all
select 'dt_reverse',   dt_reverse_status,   count(*) from classified group by dt_reverse_status
order by date_column, status

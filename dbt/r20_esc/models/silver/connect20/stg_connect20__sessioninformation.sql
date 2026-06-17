{{ config(materialized='table', table_type='iceberg', format='parquet') }}

with source as (
    select * from {{ source('connect20_bronze', 'connect20_sessioninformation') }}
),

-- Dedup is commented out: Connect20 bronze uses incremental append where
-- each daily file contains only new records, so duplicate rows per
-- compisite key or PK are not expected. Uncomment if upstream starts
-- resending existing attendance records and deduplication becomes a requirement.
deduped as (
    select *
    --    , row_number() over (
    --         partition by pk_column
    --         order by ingested_at desc
    --     ) as _rn
    from source
),

renamed as (
    select
        -- Keys
        cast(sessionid as integer)          as session_id,
        useremail,

        -- Session
        session_title,
        cast(date_started as timestamp)     as date_started,
        cast(date_ended as timestamp)       as date_ended,
        cast(date_attended as timestamp)    as date_attended,
        meeting_room_name,
        session_schedule_dates,

        -- Attendee
        firstname,
        lastname,
        completed,
        group_member_of,
        multi_credit_override,

        -- Payment
        cast(sessionfee as double)          as session_fee,
        paymentmethod                       as payment_method,
        cast(feepaid as decimal(38,18))     as fee_paid,
        promotional_codes,

        -- Organization
        organization,
        district,
        identification_code,
        customer_number,
        site_type,
        member_group,

        -- Audit
        file_name,
        file_date,
        ingested_at
    from deduped
  --  where _rn = 1
)

select * from renamed

{{
  config(
    materialized='table',
    table_type='iceberg'
  )
}}

SELECT *
FROM {{ source('silver', 'silver_no_pk_log_data') }}

{{
  config(
    materialized='table',
    table_type='iceberg'
  )
}}

SELECT *
FROM {{ source('silver', 'silver_clob_master_pk') }}

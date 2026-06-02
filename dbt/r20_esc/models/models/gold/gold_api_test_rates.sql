{{
  config(
    materialized='table',
    table_type='iceberg'
  )
}}

SELECT *
FROM {{ source('silver', 'silver_api_test_rates') }}

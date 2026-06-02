{{
  config(
    materialized='table',
    table_type='iceberg'
  )
}}

SELECT *
FROM {{ source('silver', 'silver_blob_assets_pk') }}

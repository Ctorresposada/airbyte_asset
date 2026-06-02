{{
  config(
    materialized='incremental',
    unique_key='ASSET_ID',
    table_type='iceberg',
    incremental_strategy='merge'
  )
}}

SELECT *
FROM {{ source('bronze', 'blob_assets_pk') }}

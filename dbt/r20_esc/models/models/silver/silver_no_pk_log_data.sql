{{
  config(
    materialized='incremental',
    unique_key='_AIRBYTE_RAW_ID',
    table_type='iceberg',
    incremental_strategy='merge'
  )
}}

SELECT *
FROM {{ source('bronze', 'no_pk_log_data') }}

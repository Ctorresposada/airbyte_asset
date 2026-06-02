{{
  config(
    materialized='incremental',
    unique_key='ID',
    table_type='iceberg',
    incremental_strategy='merge'
  )
}}

SELECT *
FROM {{ source('bronze', 'clob_master_pk') }}

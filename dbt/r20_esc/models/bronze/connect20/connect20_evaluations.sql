-- Bronze table: 1:1 copy of Connect20 / ESCworks evaluation responses
-- from raw Parquet. Types are already correct in the source (timestamps,
-- decimals, ints) so no cast is needed. Materialized as Iceberg in
-- escr20_bronze_dev for downstream silver staging.
{{ config(materialized='table', table_type='iceberg', format='parquet') }}

select *
from {{ source('connect20_raw', 'connect20_parquet') }}

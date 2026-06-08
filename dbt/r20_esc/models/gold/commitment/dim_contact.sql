with contacts as (
    select * from {{ source('silver', 'stg_oracle__contact') }}
)

select
    contact_id,
    first_name,
    last_name,
    full_name
from contacts

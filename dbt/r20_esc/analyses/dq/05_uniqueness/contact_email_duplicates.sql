-- DQ analysis: duplicate email_address in contact (top 20 by frequency)
-- Observed 2026-06-10: max duplicate count 17 (chris.black@esc9.net);
--   several emails appearing 8-12 times.
-- Threshold for test promotion: client should confirm whether email
--   uniqueness is a contract or whether duplicates represent valid
--   re-use (e.g. shared mailbox per role). If contract, promote to
--   `unique` test on the source column.

select
    email_address,
    count(*) as dup_count
from {{ source('oracle', 'contact') }}
where email_address is not null
group by email_address
having count(*) > 1
order by dup_count desc
limit 20

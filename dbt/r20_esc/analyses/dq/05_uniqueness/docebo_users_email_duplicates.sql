-- DQ analysis: duplicate emails in docebo_users_src (top 20 by frequency)
-- Observed 2026-06-10: 6 rows with empty email; max real duplicate
--   appears 3 times (melissa.alvarado@esc20.net).
-- Threshold for test promotion: lower volume than Oracle contact;
--   client should confirm whether multiple Docebo accounts per email
--   are valid.

select
    email,
    count(*) as dup_count
from {{ source('docebo', 'docebo_users_src') }}
where email is not null
group by email
having count(*) > 1
order by dup_count desc
limit 20

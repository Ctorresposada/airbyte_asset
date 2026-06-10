-- DQ analysis: FK orphans docebo_enrollments_src -> docebo_users_src
-- enrollments.user_id is double, users.user_id is varchar; cast to
-- normalize.
-- Observed 2026-06-10: 0 orphans out of 11080 — perfect referential
--   integrity once types are aligned.
-- Threshold for test promotion: hard fail on any orphan
--   (relationships test on the source column once contract holds).

select
    count(*) as total,
    sum(case when u.user_id is null then 1 else 0 end) as orphans
from {{ source('docebo', 'docebo_enrollments_src') }} e
left join {{ source('docebo', 'docebo_users_src') }} u
    on cast(cast(e.user_id as bigint) as varchar) = u.user_id

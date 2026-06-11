-- DQ analysis: distinct values of status enum columns in Docebo bronze
-- Observed 2026-06-10:
--   docebo_courses_src.status: NULL in all 2017 rows — no published courses
--   docebo_enrollments_src.enrollment_status: enrolled (11003), completed (38),
--                                             in_progress (39)
-- Threshold for test promotion:
--   - course.status: client should confirm whether NULL is expected
--     (likely a source-side bug; populated values should include 'published').
--   - enrollment_status: accepted_values once full enum confirmed
--     (likely {enrolled, in_progress, completed, suspended, ...}).

select 'docebo_courses_src.status'              as col, status            as value, count(*) as n
  from {{ source('docebo', 'docebo_courses_src') }}      group by status
union all
select 'docebo_enrollments_src.enrollment_status', enrollment_status, count(*)
  from {{ source('docebo', 'docebo_enrollments_src') }} group by enrollment_status
order by col, value

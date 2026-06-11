-- DQ analysis: invalid date_created years in contact
-- Background: contact.date_created is stored as varchar (not date) in
--   bronze. Some rows have malformed year parts.
-- Observed 2026-06-10: 141+ rows with years outside 2000-2099 range,
--   spread across '0008', '0009', '0010', ..., '0023', '301'.
--   2 rows in 2026 (current/near-future), 4 in 2025.
-- Threshold for test promotion: warn if any row has SUBSTR(date_created, 1, 4)
--   outside [{first_valid_year}, current_year + 1]. Need client to
--   confirm acceptable lower bound (2000? 2007?).

select
    substr(date_created, 1, 4) as year_part,
    count(*) as n
from {{ source('oracle', 'contact') }}
where date_created < '2000' or date_created > '2099'
group by substr(date_created, 1, 4)
order by year_part

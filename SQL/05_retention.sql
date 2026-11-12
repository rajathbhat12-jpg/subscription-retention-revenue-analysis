-- 05_retention.sql

-- Cohort retention. Cohort = users grouped by signup month (users_clean).
-- "Active" in a month = at least one event in events_clean that month.
-- months_since_signup: 0 = signup month, 1 = next month, and so on.
-- Data is synthetic.

-- Finding:
--   January 2025 cohort: 99.6% in month 0, 76.3% in month 1, 53.3% in month 2,
--   22.6% in month 3, then a flat tail of about 6-9%. Most users go quiet within
--   about three months; the tail is probably mostly paying customers.
-- Note: month 0 is slightly under 100% (686 of 689 for January 2025) because some
--   signup events were removed in cleaning (events dated before signup).
-- Note: later cohorts have fewer months of history, so their later months are
--   missing, not zero.

WITH active_months AS (
    SELECT DISTINCT user_id,
           DATE_TRUNC('month', event_time)::date AS activity_month
    FROM events_clean
),
month_numbers AS (
    SELECT a.user_id,
           DATE_TRUNC('month', u.signup_date)::date AS cohort_month,
           a.activity_month,
           EXTRACT(YEAR FROM a.activity_month) * 12 + EXTRACT(MONTH FROM a.activity_month) AS activity_month_number,
           EXTRACT(YEAR FROM u.signup_date) * 12 + EXTRACT(MONTH FROM u.signup_date) AS cohort_month_number
    FROM active_months a
    INNER JOIN users_clean u ON a.user_id = u.user_id
),
retention_counts AS (
    SELECT cohort_month,
       activity_month_number - cohort_month_number AS months_since_signup,
	   COUNT(DISTINCT user_id) AS active_users
FROM month_numbers
GROUP BY cohort_month , months_since_signup
ORDER BY cohort_month , months_since_signup
),
cohort_sizes AS (
   SELECT DATE_TRUNC('month', signup_date)::date AS cohort_month,
           COUNT(*) AS cohort_size
    FROM users_clean
    GROUP BY DATE_TRUNC('month', signup_date)::date
)
SELECT r.cohort_month,
       r.months_since_signup,
       r.active_users,
       c.cohort_size,
       ROUND(r.active_users * 100.0 / c.cohort_size, 1) AS retention_pct
FROM retention_counts r
INNER JOIN cohort_sizes c ON r.cohort_month = c.cohort_month
ORDER BY r.cohort_month, r.months_since_signup;


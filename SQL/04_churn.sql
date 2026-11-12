-- 04_churn.sql
-- Churn analysis on subscriptions_clean. Data is synthetic and "as of"
-- the end of September 2026.
-- Churn = a paying customer cancelling (status = 'cancelled', end_date filled in).

-- =====================================================
-- Step 1: overall churn

-- Finding: 1,228 of 2,851 subscriptions have cancelled (43.1%); 1,623 are active.
-- Caveat: this number mixes old and new customers. A recent customer has had
--         little time to cancel, so it understates eventual churn and can't
--         show whether things are getting better or worse. Monthly churn
--         (Step 3) is the fairer view.

SELECT COUNT(*) AS total,
       COUNT(*) FILTER (WHERE status = 'active') AS active,
       COUNT(*) FILTER (WHERE status = 'cancelled') AS cancelled,
       ROUND(COUNT(*) FILTER (WHERE status = 'cancelled') * 100.0 / COUNT(*), 1) AS churn_rate_pct
FROM subscriptions_clean;

-- =====================================================
-- Step 2: churn by plan

-- Finding: Basic has the most customers (1,546) and the most cancellations (640),
--          but that is just because it is the biggest plan. By churn RATE, Pro is
--          highest (46.8%), Basic 41.4%, Premium lowest (38.9%).
--          The spread is modest and Premium is small (293 customers), so the
--          differences are probably noise. No recommendation based on plan.

SELECT plan,
       COUNT(*) AS total,
       COUNT(*) FILTER (WHERE status = 'cancelled') AS cancelled,
       ROUND(COUNT(*) FILTER (WHERE status = 'cancelled') * 100.0 / COUNT(*), 1) AS churn_rate_pct
FROM subscriptions_clean
GROUP BY plan
ORDER BY plan;

-- =====================================================
-- Step 3: monthly churn rate

-- Step 3a: monthly churn for ONE month (March 2026), to understand the logic

-- Definition: monthly churn rate = customers who cancelled during the month
--             / customers who were paying at the start of the month
-- Finding: 1,230 customers at the start of March; 74 cancelled during March
--          => 6.0% monthly churn
-- =====================================================
SELECT COUNT(*) AS customers_at_start
FROM subscriptions_clean
WHERE start_date < '2026-03-01'
  AND (end_date IS NULL OR end_date >= '2026-03-01');

SELECT COUNT(*) AS cancelled_in_march
FROM subscriptions_clean
WHERE end_date >= '2026-03-01'
  AND end_date < '2026-04-01';
-- =====================================================
-- Step 3b: monthly churn rate, all months (Jan 2025 - Sep 2026)

-- Question: is churn rising, falling or flat?
-- Method: generate_series builds one row per month; each month is joined to the
--         subscriptions active at its start; the FILTER counts those that ended
--         before the next month began.
-- Check: the March 2026 row matches the hand calculation (1,230 / 73 / 5.9%).
-- Finding: Monthly churn settled into a 6-8% band by mid-2025 (about 6.6% on
--          average) and has stayed flat through September 2026. Early months
--          were lower because the customer base was small and young. More
--          customers leave each month in absolute terms (3 -> ~75-100) only
--          because the base grew (68 -> 1,562), not because the rate rose.
--          At ~6.6% monthly churn, the average customer stays about 15 months.
-- =====================================================
WITH months AS (
    SELECT d::date AS month_start
    FROM generate_series('2025-01-01'::date, '2026-09-01'::date, interval '1 month') AS d
)
SELECT m.month_start,
       COUNT(s.subscription_id) AS customers_at_start,
       COUNT(s.subscription_id) FILTER (WHERE s.end_date < m.month_start + interval '1 month') AS cancelled,
       ROUND(
           COUNT(s.subscription_id) FILTER (WHERE s.end_date < m.month_start + interval '1 month')
           * 100.0 / NULLIF(COUNT(s.subscription_id), 0), 1
       ) AS churn_rate_pct
FROM months m
LEFT JOIN subscriptions_clean s
       ON s.start_date < m.month_start
      AND (s.end_date IS NULL OR s.end_date >= m.month_start)
GROUP BY m.month_start
ORDER BY m.month_start;
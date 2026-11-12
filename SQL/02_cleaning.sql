-- 02_cleaning.sql

-- users_clean
-- Problem: 285 duplicate users (same email), 28 country spellings
-- Fix: keep the earliest signup per email (ties broken by lowest user_id);
--      users with no email are all kept; country cleaned with UPPER/TRIM
--      and 'IN' mapped to 'INDIA'


DROP TABLE IF EXISTS users_clean;

CREATE TABLE users_clean AS
WITH numbered AS (
    SELECT user_id, name, email, signup_date, country, acquisition_channel,
           ROW_NUMBER() OVER (PARTITION BY email ORDER BY signup_date, user_id) AS row_num
    FROM users
)
SELECT
    user_id,
    name,
    email,
    signup_date,
    CASE
        WHEN UPPER(TRIM(country)) = 'IN' THEN 'INDIA'
        ELSE UPPER(TRIM(country))
    END AS country_clean,
    acquisition_channel
FROM numbered
WHERE row_num = 1 OR email IS NULL;

-- Verification:
-- SELECT COUNT(*) FROM users_clean;                       -- 15,015
-- SELECT COUNT(*) FROM users_clean WHERE email IS NULL;   -- 459
-- SELECT DISTINCT country_clean FROM users_clean;         -- 6 rows
-- =====================================================

-- subscriptions_clean

-- Problem: 28 subscriptions end before they start
-- Fix: exclude them (can't tell which date is wrong); active
--      subscriptions (no end_date) are kept
DROP TABLE IF EXISTS subscriptions_clean;

CREATE TABLE subscriptions_clean AS
SELECT *
FROM subscriptions
WHERE end_date IS NULL
   OR end_date >= start_date;

-- Verification:
-- SELECT COUNT(*) FROM subscriptions_clean;                          -- 2,851
-- SELECT COUNT(*) FROM subscriptions_clean WHERE status = 'active';  -- 1,623

-- =====================================================

-- payments_quarantine and payments_clean

-- Requires users_clean and subscriptions_clean to exist already.
-- Problems fixed:
--   1. Orphan payments (user_id not in users_clean): quarantined, not deleted
--   2. Negative amounts (105): every one equals a plan price with the sign
--      flipped, and 100 had no positive payment on the same subscription and
--      date, so they are treated as sign errors and flipped with ABS()
--   3. Missing subscription IDs (210 in the earlier version): recovered by
--      matching user_id and payment date to a subscription's start/end dates.
--      Every one could be matched, and no user has more than one subscription.
--   4. Duplicate payments: one row kept per (user, subscription, amount, date),
--      lowest payment_id. Done after steps 2 and 3 so flipped or re-linked rows
--      that become identical to their partner are also caught.
--   5. Payments pointing at a subscription excluded from subscriptions_clean
--      (its dates were contradictory): quarantined, so every payment in
--      payments_clean links to a valid user and a valid subscription.

DROP TABLE IF EXISTS payments_quarantine;

CREATE TABLE payments_quarantine AS
SELECT p.*
FROM payments p
LEFT JOIN users_clean u ON p.user_id = u.user_id
LEFT JOIN subscriptions_clean s ON p.subscription_id = s.subscription_id
WHERE u.user_id IS NULL
   OR (p.subscription_id IS NOT NULL AND s.subscription_id IS NULL);

DROP TABLE IF EXISTS payments_clean;

CREATE TABLE payments_clean AS
WITH flipped AS (
    SELECT p.payment_id,
           p.user_id,
           COALESCE(p.subscription_id, s.subscription_id) AS subscription_id,
           ABS(p.amount) AS amount,
           p.payment_date
    FROM payments p
    INNER JOIN users_clean u ON p.user_id = u.user_id
    LEFT JOIN subscriptions_clean s
           ON p.user_id = s.user_id
          AND p.payment_date >= s.start_date
          AND (s.end_date IS NULL OR p.payment_date <= s.end_date)
    LEFT JOIN subscriptions_clean s2
           ON p.subscription_id = s2.subscription_id
    WHERE p.subscription_id IS NULL
       OR s2.subscription_id IS NOT NULL
),
numbered AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY user_id, subscription_id, amount, payment_date
               ORDER BY payment_id
           ) AS row_num
    FROM flipped
)
SELECT payment_id, user_id, subscription_id, amount, payment_date
FROM numbered
WHERE row_num = 1;

-- Verification (fill in the numbers you get):
-- SELECT COUNT(*) FROM payments_quarantine;                          -- 365
-- SELECT COUNT(*) FROM payments_clean;                               -- 20,616
-- SELECT COUNT(*) FROM payments_clean WHERE amount < 0;              -- 0
-- SELECT COUNT(*) FROM payments_clean WHERE subscription_id IS NULL; -- 0
-- Duplicate-payment check (Check 9 query) on payments_clean         -- 0 groups
-- Payments in payments_clean whose subscription_id is not in
--   subscriptions_clean (LEFT JOIN ... IS NULL)                      -- 0

-- =====================================================

-- events_clean

-- Problem: 1,979 events (1,804 users) are dated before the user's signup date
-- Fix: exclude them. A correct timestamp can't be recovered, and the errors are
--      scattered (mostly one per user), so dropping them doesn't bias the analysis.
--      Joined to users_clean so all clean tables are consistent.

DROP TABLE IF EXISTS events_clean;

CREATE TABLE events_clean AS
SELECT e.* 
FROM events e
INNER JOIN users_clean u ON e.user_id = u.user_id
WHERE e.event_time::date >= u.signup_date;

-- Verification:
-- SELECT COUNT(*) FROM events_clean;   -- 196,003
-- Check 7 query on events_clean        -- 0

-- =====================================================
-- 01_data_quality_audit.sql
-- Audit of the 4 tables before any analysis.

-- Check 1: Are country values consistent?
-- Evidence query: counts each raw spelling, with brackets to reveal hidden spaces
SELECT '[' || country || ']' AS shown_value,
       COUNT(*) AS users
FROM users
GROUP BY country
ORDER BY country;
-- Finding: 28 distinct spellings for 6 countries (case, spaces, 'IN' abbreviation)

-- Fix preview: UPPER(TRIM(...)) handles case and spaces, CASE maps 'IN' to 'INDIA'
-- Result: 6 countries. Not applied to the table yet (that happens in the cleaning step).
WITH cleaned AS (
    SELECT
        user_id,
        CASE
            WHEN UPPER(TRIM(country)) = 'IN' THEN 'INDIA'
            ELSE UPPER(TRIM(country))
        END AS country_clean
    FROM users
)
SELECT country_clean,
       COUNT(*) AS users
FROM cleaned
GROUP BY country_clean
ORDER BY country_clean;

-- Check 2: Are there users with missing email id?
SELECT COUNT(*)
FROM users
WHERE email IS NULL;
-- Finding: 459 users have there email missing

-- Check 3: Are there duplicate users?
Select email,
       COUNT(*) AS times_used 
FROM users
WHERE email IS NOT NULL
GROUP BY email
HAVING COUNT(*) > 1
ORDER BY times_used DESC;
-- Finding: 285 emails appear on 2 user rows each (285 surplus rows),none of them have any payments or events.
-- Fix to apply later: keep one row per email (probably the earliest signup), delete the other

-- Check 4: Are there payments for users that don't exist?
SELECT COUNT(*)
FROM payments p
LEFT JOIN users u ON p.user_id = u.user_id
WHERE u.user_id IS NULL;
-- Finding: 211 orphan payments (about 1% of 21,185)
-- Fix to apply later: exclude from user-level analysis, or remove after confirming they aren't valid records

-- Check 5: Are there payments with a negetive amount?
SELECT count(*) AS negatives
FROM payments p1
LEFT JOIN payments p2 ON p1.subscription_id = p2.subscription_id
AND p1.payment_date = p2.payment_date
AND p2.amount > 0
WHERE p1.amount < 0
AND p2.payment_id IS NOT NULL;
-- Finding: 105 negatives; every one equals its plan's price. 100 have no positive payment on the same subscription and date (consistent with sign errors); 5 do (possible refunds or duplicate rows).
-- Fix to apply later: flip the 100 to positive; hold the 5 pending the duplicate-payments check.

-- Check 6: Are there payments which have a missing subscritpion id?
SELECT COUNT(*) AS missing_id
FROM payments
WHERE subscription_id IS NULL;
-- Findings: 211 payments have an empty susbcription id
-- Fix: recover the subscription by matching `user_id` and the payment date to a subscription's start and end dates. Exclude payments that                    can't be matched.

-- Check 7: Do any events happen before the user signed up?
SELECT 
    COUNT(*) AS total_invalid_events,
    COUNT(DISTINCT e.user_id) AS affected_users_count
FROM events e
INNER JOIN users u ON e.user_id = u.user_id
WHERE e.event_time::date < u.signup_date;
-- Finding: 1,979 events across 1,804 users, mostly one bad event per user
-- Fix: exclude the 1,979 events dated before the user's signupfrom the clean events table. A correct timestamp can't be recovered, so I won't guess one. The raw table stays untouched.

-- Check 8: Do any subscriptions end before they start?
SELECT COUNT(*) AS end_date_earlier_than_start_date
FROM subscriptions
WHERE start_date > end_date;
-- Finding: 28 subscriptions have end_date earlier than start_date
-- Fix: exclude from the clean table and log them, since the wrong date can't be identified.

-- Check 9: Are there duplicate payments?
SELECT user_id,subscription_id,amount,payment_date,COUNT(*) AS times_appeared
FROM payments
GROUP BY user_id,subscription_id,amount,payment_date
HAVING COUNT(*) > 1;
-- Finding: 200 groups of payments share the same user, subscription, date and amount
-- Fix to apply later: keep one row per group in the clean payments table






 